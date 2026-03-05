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
  source      = "groceries/secrets.env.tmpl"
  destination = "groceries/.env"
}

template {
  source      = "lil-dumpster/secrets.env.tmpl"
  destination = "lil-dumpster/.env"
}

template {
  source      = "miniflux/secrets.env.tmpl"
  destination = "miniflux/.env"
}

template {
  source      = "no-time-to-explain/secrets.env.tmpl"
  destination = "no-time-to-explain/.env"
}

template {
  source      = "tfc-agent/secrets.env.tmpl"
  destination = "tfc-agent/.env"
}

template {
  source      = "servarr/secrets.env.tmpl"
  destination = "servarr/.env"
}
