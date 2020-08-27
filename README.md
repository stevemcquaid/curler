# Curler
This is a go program to curl a specific url asynchronously. It is configurable via two cli flags:

    `-rps 10` // will send 10 requests every second
    `-url http://google.com` // will curl google.com
    `-body` // print response body of request
    `-k` // use insecure tls

# Dev usage
    `make build; ./bin/app -k -rps 2 -url https://google.com`

# Run all ci
    `make help`
    `make ci`