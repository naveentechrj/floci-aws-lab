variable "region" {
  description = "Region name. Floci accepts any region; keep us-east-1 to match the guides."
  type        = string
  default     = "us-east-1"
}

variable "floci_endpoint" {
  description = "Floci edge endpoint. From the Vagrant VM use http://localhost:4566."
  type        = string
  default     = "http://localhost:4566"
}

variable "project" {
  description = "Name prefix for every resource."
  type        = string
  default     = "floci-lab"
}

variable "tags" {
  description = "Default tags applied to every resource."
  type        = map(string)
  default = {
    Owner       = "lab-owner"
    Environment = "lab"
    ManagedBy   = "terraform"
  }
}

# ---- Network ----
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "azs" {
  description = "Two AZs so the ALB has the subnets it requires."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidr" {
  type    = string
  default = "10.0.3.0/24"
}

# ---- Compute ----
variable "ami_id" {
  description = "AMI ID as Floci lists it (aws ec2 describe-images). The guides' ami-0c55b159cbfafe1f0 may not exist in Floci."
  type        = string
  default     = "ami-0c55b159cbfafe1f0"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

# ---- Security ----
variable "ssh_public_key_path" {
  description = "Public key injected into the instance for SSH. Create the pair first (see the guide)."
  type        = string
  default     = "~/.ssh/floci-lab.pub"
}

variable "admin_cidrs" {
  description = "Source ranges allowed to SSH. Includes the Vagrant host-only network and the Docker bridge."
  type        = list(string)
  default     = ["192.168.56.0/24", "172.17.0.0/16"]
}

# ---- Storage ----
variable "static_bucket_name" {
  type    = string
  default = "my-app-static-assets"
}

variable "users_table_name" {
  type    = string
  default = "AppUsers"
}

# ---- Monitoring ----
variable "alert_forwarder_url" {
  description = "Where SNS posts alerts. The forwarder runs on the Vagrant host and relays them to Mailpit."
  type        = string
  default     = "http://172.17.0.1:5005/sns"
}

variable "probe_ports" {
  description = "Host-side ports checked by scripts/lab-metrics.sh. Each one gets a PortUp alarm. Keep in sync with PROBE_PORTS."
  type        = map(number)
  default = {
    "mailpit-ui"      = 8025
    "mailpit-smtp"    = 1025
    "floci"           = 4566
    "alert-forwarder" = 5005
    "lab-web"         = 30000
  }
}
