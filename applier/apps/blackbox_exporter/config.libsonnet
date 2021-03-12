{
  "modules": {
    "dns_test": {
      "dns": {
        "ip_protocol_fallback": false,
        "preferred_ip_protocol": "ip4",
        "query_name": "example.com",
        "validate_answer_rrs": {
          "fail_if_matches_regexp": [
            "test"
          ]
        }
      },
      "prober": "dns",
      "timeout": "5s"
    },
    "http_2xx": {
      "http": null,
      "prober": "http",
      "timeout": "5s"
    },
    "http_header_match_origin": {
      "http": {
        "fail_if_header_not_matches": [
          {
            "allow_missing": false,
            "header": "Access-Control-Allow-Origin",
            "regexp": "(\\*|example\\.com)"
          }
        ],
        "headers": {
          "Origin": "example.com"
        },
        "method": "GET"
      },
      "prober": "http",
      "timeout": "5s"
    },
    "http_post_2xx": {
      "http": {
        "basic_auth": {
          "password": "mysecret",
          "username": "username"
        },
        "method": "POST"
      },
      "prober": "http",
      "timeout": "5s"
    },
    "icmp_test": {
      "icmp": {
        "preferred_ip_protocol": "ip4"
      },
      "prober": "icmp",
      "timeout": "5s"
    },
    "irc_banner": {
      "prober": "tcp",
      "tcp": {
        "query_response": [
          {
            "send": "NICK prober"
          },
          {
            "send": "USER prober prober prober :prober"
          },
          {
            "expect": "PING :([^ ]+)",
            "send": "PONG "
          },
          {
            "expect": "^:[^ ]+ 001"
          }
        ]
      },
      "timeout": "5s"
    },
    "pop3s_banner": {
      "prober": "tcp",
      "tcp": {
        "query_response": [
          {
            "expect": "^+OK"
          }
        ],
        "tls": true,
        "tls_config": {
          "insecure_skip_verify": false
        }
      }
    },
    "smtp_starttls": {
      "prober": "tcp",
      "tcp": {
        "query_response": [
          {
            "expect": "^220 "
          },
          {
            "send": "EHLO prober"
          },
          {
            "expect": "^250-STARTTLS"
          },
          {
            "send": "STARTTLS"
          },
          {
            "expect": "^220"
          },
          {
            "starttls": true
          },
          {
            "send": "EHLO prober"
          },
          {
            "expect": "^250-AUTH"
          },
          {
            "send": "QUIT"
          }
        ]
      },
      "timeout": "5s"
    },
    "ssh_banner": {
      "prober": "tcp",
      "tcp": {
        "query_response": [
          {
            "expect": "^SSH-2.0-"
          }
        ]
      },
      "timeout": "5s"
    },
    "tcp_connect": {
      "prober": "tcp",
      "timeout": "5s"
    }
  }
}
