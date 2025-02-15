# Labinator cookbook
This [Chef cookbook](https://docs.chef.io/cookbooks/) is the foundation for configuring what I've dubbed the [labinator](https://labinator.bitnebula.com). It is responsible for setting up the environment that manages a set of nodes for experimentation with various operating systems supporting evaluation of netbooting, airgaps, failure scenarios, etc.

Roughly speaking, this cookbook sets up the "boss" node of the network with:
* [ntpd](https://docs.ntpsec.org/latest/ntpd.html) for time serving and synchronization
* [step-ca](https://smallstep.com/docs/step-ca/) to issue and sign certificates for the lab
* [dnsmasq](https://thekelleys.org.uk/dnsmasq/doc.html) to serve DHCP, DNS, and TFTP
* [Apache httpd](https://httpd.apache.org/) to serve static content and disk images
* [Prometheus](https://prometheus.io/) and [blackbox_exporter](https://github.com/prometheus/blackbox_exporter) for monitoring and metrics
* [OpenTelemetry Collector](https://github.com/open-telemetry/opentelemetry-collector) for syslog and tcplog aggregation
* [Grafana Loki](https://grafana.com/oss/loki/) for log storage and examination
* [Docker Registry](https://hub.docker.com/_/registry) for airgapped storage of containers
* [Docker CE](https://docs.docker.com/engine/install/) to run daemons/sandboxes/etc
* Several utilities and clients for poking and prodding

Each of these daemons/service represent capabilities that one can reasonably expect to find in a homelab, enterprise datacenter, or even sometimes personal networks. The daemons selected for the labinator are chosen because I personally use them at home or work, they are Open Source and freely available, and are usable for both home or enterprise purposes. That said, one should not view them as the only way to achieve the goals of the lab. For example, in a home lab dnsmasq could be replaced with a combination of [unbound](https://www.nlnetlabs.nl/projects/unbound/about/) for DNS and [Kea](https://www.isc.org/kea/) for DHCP while an enterprise ecosystem would almost always have an integrated DDI capability more appropriate to such an environment.

Because the purpose of labinator is to enable various kinds of rapid experimentation, each experiment may or may not use every daemon.

## Organization
The best way to grok this cookbook is to start with the [boss](recipes/boss.rb) recipe. The various daemons loaded onto the "boss" system are done by including a recipe responsible for setting up that service. This is done to make it as straight forward as possible to swap daemons due to personal preference or for experimentation. Unfortunately, because the daemons often depend or use each other, there is some intertwining that happens across recipes.

**NOTE**
Because building a functioning environment requires layering of services *order is important* for the standup of daemons. One cannot set up and start Apache httpd with TLS unless the lab CA is set up or a TLS cert and key are prepared.

### Attributes
Critical attributes are spread across two main files:

#### [attributes/default.rb](attributes/default.rb)
