# Port list follows the k3s networking requirements:
# https://docs.k3s.io/installation/requirements#networking
#
#   server <- internet   : 80, 443        (Traefik Ingress)
#   server <- admin_cidr : 6443           (kubectl from your laptop)
#   server <- jobe       : 6443           (agent -> API server)
#   both   <-> both      : 8472/udp       (flannel VXLAN pod network)
#   both   <-> both      : 10250          (kubelet: logs, exec, metrics)
#   jobe   <- server     : 9100           (Prometheus -> node-exporter)
#
# There is no SSH rule. Shell access is through SSM Session Manager.

resource "aws_security_group" "server" {
  name        = "${var.project}-server"
  description = "k3s server node: Ingress, API server, Moodle, MySQL, monitoring"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.project}-server" }
}

resource "aws_security_group" "jobe" {
  name        = "${var.project}-jobe"
  description = "k3s agent node dedicated to Jobe (untrusted code). No internet ingress."
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.project}-jobe" }
}

# --- server ingress ---------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "server_http" {
  security_group_id = aws_security_group.server.id
  description       = "HTTP (Let's Encrypt HTTP-01 challenge)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "server_https" {
  security_group_id = aws_security_group.server.id
  description       = "HTTPS to Traefik Ingress"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "server_api_admin" {
  security_group_id = aws_security_group.server.id
  description       = "Kubernetes API from the admin IP only"
  cidr_ipv4         = var.admin_cidr
  ip_protocol       = "tcp"
  from_port         = 6443
  to_port           = 6443
}

resource "aws_vpc_security_group_ingress_rule" "server_api_from_jobe" {
  security_group_id            = aws_security_group.server.id
  description                  = "Kubernetes API from the agent node"
  referenced_security_group_id = aws_security_group.jobe.id
  ip_protocol                  = "tcp"
  from_port                    = 6443
  to_port                      = 6443
}

resource "aws_vpc_security_group_ingress_rule" "server_vxlan_from_jobe" {
  security_group_id            = aws_security_group.server.id
  description                  = "Flannel VXLAN from the agent node"
  referenced_security_group_id = aws_security_group.jobe.id
  ip_protocol                  = "udp"
  from_port                    = 8472
  to_port                      = 8472
}

resource "aws_vpc_security_group_ingress_rule" "server_kubelet_from_jobe" {
  security_group_id            = aws_security_group.server.id
  description                  = "Kubelet from the agent node"
  referenced_security_group_id = aws_security_group.jobe.id
  ip_protocol                  = "tcp"
  from_port                    = 10250
  to_port                      = 10250
}

# --- jobe ingress (only from the server node) -------------------------------

resource "aws_vpc_security_group_ingress_rule" "jobe_vxlan_from_server" {
  security_group_id            = aws_security_group.jobe.id
  description                  = "Flannel VXLAN from the server node"
  referenced_security_group_id = aws_security_group.server.id
  ip_protocol                  = "udp"
  from_port                    = 8472
  to_port                      = 8472
}

resource "aws_vpc_security_group_ingress_rule" "jobe_kubelet_from_server" {
  security_group_id            = aws_security_group.jobe.id
  description                  = "Kubelet from the API server (logs, exec, metrics)"
  referenced_security_group_id = aws_security_group.server.id
  ip_protocol                  = "tcp"
  from_port                    = 10250
  to_port                      = 10250
}

resource "aws_vpc_security_group_ingress_rule" "jobe_node_exporter_from_server" {
  security_group_id            = aws_security_group.jobe.id
  description                  = "Prometheus scraping node-exporter"
  referenced_security_group_id = aws_security_group.server.id
  ip_protocol                  = "tcp"
  from_port                    = 9100
  to_port                      = 9100
}

# --- egress -----------------------------------------------------------------
# Nodes need outbound HTTPS for image pulls, the k3s installer, SSM and S3.
# Jobe *pods* get no egress at all; that is enforced inside the cluster by a
# NetworkPolicy (k8s/jobe/jobe.yaml), not here.

resource "aws_vpc_security_group_egress_rule" "server_all" {
  security_group_id = aws_security_group.server.id
  description       = "All outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "jobe_all" {
  security_group_id = aws_security_group.jobe.id
  description       = "All outbound (node-level: image pulls, SSM)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
