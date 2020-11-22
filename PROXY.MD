# Caddy Proxy Server

## Caddy Service File
```bash
[Unit]
Description=Caddy HTTP/2 web server
Documentation=https://caddyserver.com/docs
Wants=network-online.target
After=network-online.target

[Service]
Restart=on-failure

; User and group the process will run as.
User=felix
Group=felix

; Letsencrypt-issued certificates will be written to this directory.
Environment=CLOUDFLARE_API_TOKEN=CLOUDFLARETOKENHERE
Environment=GOOGLE_CLIENT_ID=YOURCLIENTID
Environment=GOOGLE_CLIENT_SECRET=YOURSECRET
Environment=JWT_SECRET=MADEUPSECRETKEY
Environment=JWT_ISSUER=MADEUPISSUERKEY

ExecStart=/usr/local/bin/caddy run --config /opt/caddy/Caddyfile
ExecReload=/bin/kill -USR1 $MAINPID

; Use graceful shutdown with a reasonable timeout
KillMode=mixed
KillSignal=SIGQUIT
TimeoutStopSec=5s
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
```

## Google Authentication

For now while Caddy updates the automated build process, I download from:

https://caddyserver.com/download

And pick the following plugins as I use CloudFlare and Google oAuth2:

- github.com/caddy-dns/cloudflare
- github.com/greenpau/caddy-auth-jwt
- github.com/greenpau/caddy-auth-portal

I use proxy entries for all my items behind and Google oAuth for my login validation:

```bash
# These are the default settings and I store all my items in /opt for my applications I run
{
  storage file_system {
    root /opt/caddy/ssl
  }
}

# This is no authentication and just how I serve OMBI
ombi.domain.us {
tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
}
log {
        output file /opt/caddy/logs/ombi.log
        format single_field common_log
}
reverse_proxy localhost:5000
}

# Every thing in this section is secured by the auth portal
apps.domain.us {
tls     {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }

log     {
        output file /opt/caddy/logs/apps.log
        format single_field common_log
        }

    route /auth* {
        auth_portal {
            path /auth
            backends {
                google_oauth2_backend {
                    method oauth2
                    realm google
                    provider google
                    client_id {$GOOGLE_CLIENT_ID}
                    client_secret {$GOOGLE_CLIENT_SECRET}
                    scopes openid email profile
                    user user@domain.us add role verified
                }
            }
            jwt {
                token_name access_token
                token_secret {$JWT_SECRET}
                token_issuer {$JWT_ISSUER}
                token_lifetime 604800
            }
                }
     }

    route /tautulli* {
        jwt {
          primary yes
          trusted_tokens {
            static_secret {
              token_name access_token
              token_secret {$JWT_SECRET}
            }
          }
          auth_url /auth
          allow roles verified
        }
        reverse_proxy localhost:8181
    }

    route /sonarr* {
        jwt
        reverse_proxy localhost:8989
    }

    route /radarr* {
        jwt
        reverse_proxy localhost:7878
        }

    route /bazarr* {
        jwt
        reverse_proxy localhost:6767
        }

    route /nzbget* {
        jwt
        reverse_proxy localhost:9876
        }

    route /jackett* {
        jwt
        reverse_proxy localhost:9117
        }

    route /webssh* {
        jwt
        uri strip_prefix /webssh
        reverse_proxy localhost:7676
        }

    route /monit* {
        jwt
        uri strip_prefix /monit
        reverse_proxy localhost:2812
        }

    route /grafana* {
        jwt
        uri strip_prefix /grafana
        reverse_proxy localhost:3333
        }

    route /qbit* {
        jwt
        uri strip_prefix /qbit
        reverse_proxy localhost:8080
        }

}
```

## Caddy Plex Configuration

I use [Caddy](https://github.com/mholt/caddy) as a proxy server and if you want to use it with Plex, there is a very simple config below that I used. I have since removed this from my config to help simplify things.

My plex configuration in my CaddyFile as follows:

```bash
plex.domain.us {
tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
}
reverse_proxy localhost:32400
log {
        output file /opt/caddy/logs/plex.log
        format single_field common_log
}
}
```

Plex also needs to have a few additional steps to be added so Caddy is used in all situations.

### Plex Configuration

Remote Access - Disable

```
Network - Custom server access URLs = https://<your-domain>:443,http://<your-domain>:80
```
Network - Secure connections = Preferred

<i>Note: You can force SSL by setting required and not adding the HTTP URL, however some players which do not support HTTPS (e.g: Roku, Playstations, some SmartTVs) will no longer function. I only use SSL is my config and as I do not open up HTTP traffic. </i>

### Stopping Local Access
By default, Plex regardless of what override URL you set will still connect locally to 32400. To remove this, I use the second option of adding the option to the Preferences.xml. You need to stop Plex and add the line in near the end of your Preferences.xml

allowLocalhostOnly="1" 

UFW or other firewall:
- Deny port 32400 externally (Plex still pings over 32400, some clients may use 32400 by mistake despite 443 and 80 being set).