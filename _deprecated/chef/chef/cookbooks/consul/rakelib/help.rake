# frozen_string_literal: true

# ----------------------------------------------------------------------------
# Documentation Help
# ----------------------------------------------------------------------------
desc 'Prints out all available rake tasks with descriptions, grouped and nicely formatted'
task :help do
  puts "\nAVAILABLE RAKE TASKS:\n\n"

  all_tasks = Rake.application.tasks

  # Group by first namespace or top-level
  grouped = all_tasks.group_by do |task|
    parts = task.name.split(':')
    parts.length == 1 ? 'TOP-LEVEL TASKS' : "#{parts.first.upcase} TASKS"
  end

  max_len = all_tasks.map { |t| t.name.length }.max || 0

  grouped.sort.each do |namespace, tasks|
    puts "#{namespace}:"
    tasks.sort_by(&:name).each do |task|
      printf "  %-#{max_len}s    # %s\n", task.name, (task.full_comment || '(no description)')
    end
    puts ''
  end
end
Rake::Task['help'].comment = 'Prints out all available rake tasks with descriptions, grouped and nicely formatted. Usage: rake help'
