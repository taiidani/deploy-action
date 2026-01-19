auto_auth {
  method {
    type = "token_file"

    config {
      token_file_path = "/home/rnixon/.vault-token"
    }
  }
}

template {
  source      = "gitea/secrets.env.tmpl"
  destination = "gitea/.env"
}

template {
  source      = "lil-dumpster/secrets.env.tmpl"
  destination = "lil-dumpster/.env"
}

template {
  source      = "tfc-agent/secrets.env.tmpl"
  destination = "tfc-agent/.env"
}
