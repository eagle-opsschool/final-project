# Opsschool final-project

This project is an AWS VPC+subnet that runs dockerise wikimedia on a k8s cluster.

Wikimedia is discovered using three-way consul cluster, and load-balanced using haproxy. The system is monitored using prometheus+exporters and grafana, icinga2 and ELK+filebeat. The service is A/B deployed using jenkins.

## Configuration
The project assume one has ~/.aws/credentials set. Also, one should add to variables.tf one's ssh key path and name.

## Usage
```bash
git clone https://github.com/eagle-opsschool/final-project.git
cd final-project
terraform init
terraform apply --auto-approve
```

Running this should take about 10 minutes.

The creation script will output the ip address from which the site is reachable.

## License
Public domain
