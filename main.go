package main

import (
	"context"
	"crypto/tls"
	"flag"
	"io/ioutil"
	"net"
	"net/http"
	"time"

	"github.com/sirupsen/logrus"
)

func main() {
	// Configure the logger
	log := logrus.New()
	log.Formatter = &logrus.JSONFormatter{}
	log.Level = logrus.DebugLevel

	// Read CLI flags:
	url := flag.String("url", "http://google.com", "URL to curl")
	rps := flag.Int("rps", 1, "the number of requests to send every second")
	body := flag.Bool("body", false, "print out response body in logs")
	insecure := flag.Bool("k", false, "use insecure TLS")

	// Once all flags are declared, call `flag.Parse()`
	// to execute the command-line parsing.
	flag.Parse()

	config := &Configuration{
		PrintBody: *body,
		InsecureSkipVerify: *insecure,
	}
	c := &Curler{
		Logger: log,
		Config: config,
	}

	sleepTime := 1000 / *rps

	for {
		// Run these goroutines in parallel, then sleep for a second
		go c.Curl(*url)
		time.Sleep(time.Duration(sleepTime) * time.Millisecond)
	}
}
type Configuration struct{
	PrintBody bool // Print out response bosy in logs
	InsecureSkipVerify bool // use insecure TLS
}

type Curler struct {
	Logger *logrus.Logger
	Config *Configuration
}

func (c *Curler) Curl(url string) {
	log := c.Logger.WithField("url", url)
	timeout := 3 * time.Second

	var tlsConfig *tls.Config
	if c.Config.InsecureSkipVerify {
		tlsConfig = &tls.Config{InsecureSkipVerify: true}
	}

	client := &http.Client{
		Transport: &http.Transport{
			DialContext: (&net.Dialer{
				Timeout:   timeout,
				KeepAlive: timeout,
			}).DialContext,
			/* #nosec */
			TLSClientConfig:       tlsConfig,
			TLSHandshakeTimeout:   timeout,
			ResponseHeaderTimeout: timeout,
			ExpectContinueTimeout: timeout,
		},
	}

	start := time.Now()

	req, _ := http.NewRequestWithContext(context.TODO(), "GET", url, nil)
	resp, err := client.Do(req)
	if err != nil {
		log.Error(err)
	}
	defer resp.Body.Close()

	bodyBytes, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		log.Error(err)
	}
	bodyString := string(bodyBytes)

	end := time.Since(start)

	if c.Config.PrintBody {
		log.WithField("status_code", resp.StatusCode).WithField("total_time", end.String()).Info(bodyString)
	} else {
		log.WithField("status_code", resp.StatusCode).WithField("total_time", end.String()).Info("")
	}

}
