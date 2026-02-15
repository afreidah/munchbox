default:
{{- with secret "secret/data/proxmox" }}
  user: "{{ .Data.data.user }}"
  password: "{{ .Data.data.password }}"
{{- end }}
  verify_ssl: false
