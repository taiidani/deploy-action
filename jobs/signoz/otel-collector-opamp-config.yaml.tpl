server_endpoint: ws://{{ range nomadService "signoz-query-service-ws" }}{{ .Address }}:{{ .Port }}{{ end }}/v1/opamp
