# Floci AWS Lab - Terraform bundle

Infrastructure as code for the Floci lab, split into the five categories in the lab guide.

| Category   | File(s)                  | What it builds                                                        |
|------------|--------------------------|-----------------------------------------------------------------------|
| Network    | network.tf               | VPC, 2 public + 1 private subnet, IGW, NAT (conceptual), route tables |
| Compute    | compute.tf               | EC2 web instance, ALB, target group, health check, listener           |
| Storage    | storage.tf               | S3 bucket + index.html, DynamoDB AppUsers table + usr-101, SQS DLQ    |
| Security   | security.tf              | Security groups (ALB -> web chain), key pair, IAM role/profile, operator user |
| Monitoring | monitoring.tf            | SNS topic -> HTTP forwarder, CloudWatch alarms, log metric filter     |
| Support    | provider.tf, variables.tf, outputs.tf | Floci endpoints, inputs, outputs                         |

Scripts and apps (run outside Terraform, because they act inside the instance or host):

- `scripts/bootstrap-web.sh` configures the instance container (Nginx, Gunicorn/Flask, sshd).
- `scripts/lab-metrics.sh` pushes port and disk metrics. Run it from cron.
- `alert-forwarder/forwarder.py` relays SNS alerts to Mailpit.
- `app/` contains the Flask API and the Nginx site.

## Run order

```bash
# 0. Floci with persistent storage and Mailpit running (see guide section 5 and 6)
# 1. Create the SSH key pair for the lab
ssh-keygen -t ed25519 -f ~/.ssh/floci-lab -N ""

# 2. Start the alert forwarder (SNS needs it reachable before apply)
python3 alert-forwarder/forwarder.py &

# 3. Configure and apply
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan -out tfplan
terraform apply tfplan

# 4. Configure the web instance (container name from docker ps)
./scripts/bootstrap-web.sh <ec2_container_name> ~/.ssh/floci-lab.pub

# 5. Start metrics collection (cron example in lab-metrics.sh)
```

## Know before you run

- Nothing here has been run against Floci yet. `terraform validate` and `plan` are the first checks. Expect to fix a few resource arguments against Floci's real behaviour.
- Floci does not emulate NAT traffic, so the NAT resources and the `nat_port_allocation` alarm are for learning.
- Floci's AMI IDs may differ from the guides. Set `ami_id` from `aws ec2 describe-images`.
- The operator access key is stored in `terraform.tfstate`. Keep state local and never commit it.
- Terraform cannot configure software inside a container. That's why bootstrap-web.sh exists.
