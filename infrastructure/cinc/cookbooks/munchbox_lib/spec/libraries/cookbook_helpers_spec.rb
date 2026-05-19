# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tmpdir'

# -------------------------------------------------------------------------------
# Test fixture helpers
#
# Builds a throwaway on-disk cookbook tree per example so we can exercise the
# real `find_cookbook_root` + `parse_metadata_name` codepaths without mocking
# the filesystem. Each example gets its own tmpdir, which rspec cleans up.
# -------------------------------------------------------------------------------

def write_metadata(dir, name)
  FileUtils.mkdir_p(dir)
  File.write(File.join(dir, 'metadata.rb'), <<~RB)
    name '#{name}'
    version '0.1.0'
  RB
end

def write_file(path, contents = '')
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, contents)
  path
end

# -------------------------------------------------------------------------------

RSpec.describe MunchboxLibCookbook::Helpers do
  let(:tmp) { Dir.mktmpdir('munchbox_lib_spec') }
  after { FileUtils.remove_entry(tmp) }

  describe '.cookbook' do
    # --- Returns the cookbook name parsed from metadata.rb ---
    it 'returns the cookbook name parsed from the caller cookbook metadata' do
      write_metadata(tmp, 'my_cookbook')
      caller_path = write_file(File.join(tmp, 'recipes/default.rb'))
      expect(described_class.cookbook(caller_path)).to eq('my_cookbook')
    end

    # --- Resolves the cookbook even when the caller is deeply nested ---
    it 'walks upward through nested directories to find metadata.rb' do
      write_metadata(tmp, 'deep_cookbook')
      caller_path = write_file(File.join(tmp, 'resources/nested/very/deep_resource.rb'))
      expect(described_class.cookbook(caller_path)).to eq('deep_cookbook')
    end

    # --- Caches per caller path so repeated calls do no I/O ---
    it 'memoizes the result per caller path' do
      write_metadata(tmp, 'cached')
      caller_path = write_file(File.join(tmp, 'recipes/server.rb'))
      first = described_class.cookbook(caller_path)
      allow(File).to receive(:foreach).and_call_original
      described_class.cookbook(caller_path)
      described_class.cookbook(caller_path)
      expect(File).not_to have_received(:foreach)
      expect(first).to eq('cached')
    end

    # --- Two files in the same cookbook share the parsed metadata ---
    it 'reuses the parsed metadata across different callers in the same cookbook' do
      write_metadata(tmp, 'shared_parse')
      caller_a = write_file(File.join(tmp, 'recipes/a.rb'))
      caller_b = write_file(File.join(tmp, 'resources/b.rb'))
      described_class.cookbook(caller_a)
      allow(File).to receive(:foreach).and_call_original
      expect(described_class.cookbook(caller_b)).to eq('shared_parse')
      expect(File).not_to have_received(:foreach)
    end

    # --- Tolerates double-quoted name directive in metadata.rb ---
    it 'handles double-quoted name in metadata.rb' do
      FileUtils.mkdir_p(tmp)
      File.write(File.join(tmp, 'metadata.rb'), %(name "double_quoted"\nversion "0.1.0"\n))
      caller_path = write_file(File.join(tmp, 'recipes/default.rb'))
      expect(described_class.cookbook(caller_path)).to eq('double_quoted')
    end

    # --- Raises a clear error when no metadata.rb is anywhere above ---
    it 'raises a helpful error when no metadata.rb is found above the caller' do
      orphan = write_file(File.join(tmp, 'lonely.rb'))
      expect { described_class.cookbook(orphan) }
        .to raise_error(/no metadata\.rb found above/)
    end

    # --- Raises a clear error when metadata.rb exists but has no name ---
    it 'raises when metadata.rb has no name directive' do
      FileUtils.mkdir_p(tmp)
      File.write(File.join(tmp, 'metadata.rb'), %(version '0.1.0'\n))
      caller_path = write_file(File.join(tmp, 'recipes/default.rb'))
      expect { described_class.cookbook(caller_path) }
        .to raise_error(/no `name` directive/)
    end
  end

  describe '.reset_cache!' do
    # --- Clears both internal caches so the next call re-reads metadata ---
    it 'forces the next call to re-walk and re-parse' do
      write_metadata(tmp, 'before')
      caller_path = write_file(File.join(tmp, 'recipes/default.rb'))
      expect(described_class.cookbook(caller_path)).to eq('before')

      File.write(File.join(tmp, 'metadata.rb'), %(name 'after'\nversion '0.2.0'\n))
      described_class.reset_cache!
      expect(described_class.cookbook(caller_path)).to eq('after')
    end
  end
end
