{{ with secret "pki_int/cert/ca" }}{{ .Data.certificate }}{{ end }}
{{ with secret "pki/cert/ca" }}{{ .Data.certificate }}{{ end }}
