{
    "file": 3,
    "format": 1
}{
    "base": "/",
    "cert": "ssl/daemon.cert",
    "default_daemon": "",
    "enabled_plugins": [],
    "first_login": false,
    "https": false,
    "interface": "0.0.0.0",
    "language": "",
    "pkey": "ssl/daemon.pkey",
    "port": 8112,
{{ with secret "secret/data/deluge" }}
    "pwd_salt": "{{ .Data.data.pwd_salt }}",
    "pwd_sha1": "{{ .Data.data.pwd_sha1 }}",
{{ end }}
    "session_timeout": 3600,
    "show_session_speed": false,
    "show_sidebar": true,
    "sidebar_multiple_filters": true,
    "sidebar_show_zero": false,
    "theme": "gray"
}
