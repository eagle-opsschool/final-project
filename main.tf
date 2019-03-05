provider "aws" {
  shared_credentials_file = "~/.aws/credentials"
  region                  = "${var.aws_region}"
}

resource "aws_vpc" "final_project_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "final_project_public_subnet" {
  vpc_id            = "${aws_vpc.final_project_vpc.id}"
  cidr_block        = "10.0.0.0/24"
  availability_zone = "us-east-2b"

  map_public_ip_on_launch = true
  tags {
    Name = "final_project_public_subnet"
  }
}

resource "aws_subnet" "final_project_private_subnet" {
  vpc_id            = "${aws_vpc.final_project_vpc.id}"
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-2b"

  #map_public_ip_on_launch = true
  tags {
    Name = "final_project_private_subnet"
  }
}

resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.final_project_vpc.id}"
}

resource "aws_security_group" "nat" {
    name = "vpc_nat"
    description = "Allow traffic to pass from the private subnet to the internet"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

#    ingress {
#        from_port = 80
#        to_port = 80
#        protocol = "tcp"
#        cidr_blocks = ["${aws_subnet.final_project_private_subnet.cidr_block}"]
#    }
#    ingress {
#        from_port = 443
#        to_port = 443
#        protocol = "tcp"
#        cidr_blocks = ["${aws_subnet.final_project_private_subnet.cidr_block}"]
#    }
#    ingress {
#        from_port = 22
#        to_port = 22
#        protocol = "tcp"
#        cidr_blocks = ["0.0.0.0/0"]
#    }
#    ingress {
#        from_port = -1
#        to_port = -1
#        protocol = "icmp"
#        cidr_blocks = ["0.0.0.0/0"]
#    }

#    egress {
#        from_port = 80
#        to_port = 80
#        protocol = "tcp"
#        cidr_blocks = ["0.0.0.0/0"]
#    }
#    egress {
#        from_port = 443
#        to_port = 443
#        protocol = "tcp"
#        cidr_blocks = ["0.0.0.0/0"]
#    }
#    egress {
#        from_port = 22
#        to_port = 22
#        protocol = "tcp"
#        cidr_blocks = ["${aws_vpc.final_project_vpc.cidr_block}"]
#    }
#    egress {
#        from_port = -1
#        to_port = -1
#        protocol = "icmp"
#        cidr_blocks = ["0.0.0.0/0"]
#    }

    vpc_id = "${aws_vpc.final_project_vpc.id}"

    tags {
        Name = "NATSG"
    }
}

resource "aws_instance" "nat" {
    ami = "ami-882914ed" # this is a special ami preconfigured to do NAT
    availability_zone = "us-east-2b"
    instance_type = "t2.micro"
    private_ip    = "10.0.0.100"
    key_name = "${var.aws_key_name}"
    vpc_security_group_ids = ["${aws_security_group.nat.id}"]
    subnet_id = "${aws_subnet.final_project_public_subnet.id}"
    associate_public_ip_address = true
    source_dest_check = false

    tags {
        Name = "VPC NAT"
    }
}

resource "aws_eip" "nat" {
    instance = "${aws_instance.nat.id}"
    vpc = true
}

#resource "aws_eip" "mysql" {
#    instance = "${aws_instance.mysql_master.id}"
#    vpc = true
#}

resource "aws_route_table" "final_project_public_subnet" {
    vpc_id = "${aws_vpc.final_project_vpc.id}"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.default.id}"
    }

    tags {
        Name = "Public Subnet"
    }
}

resource "aws_route_table_association" "final_project_public_subnet" {
    subnet_id = "${aws_subnet.final_project_public_subnet.id}"
    route_table_id = "${aws_route_table.final_project_public_subnet.id}"
}

resource "aws_route_table" "final_project_private_subnet" {
    vpc_id = "${aws_vpc.final_project_vpc.id}"

    route {
        cidr_block = "0.0.0.0/0"
        instance_id = "${aws_instance.nat.id}"
    }

    tags {
        Name = "Private Subnet"
    }
}

resource "aws_route_table_association" "final_project_private_subnet" {
    subnet_id = "${aws_subnet.final_project_private_subnet.id}"
    route_table_id = "${aws_route_table.final_project_private_subnet.id}"
}

resource "aws_security_group" "final_project_public_security_group" {
  vpc_id = "${aws_vpc.final_project_vpc.id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["${aws_subnet.final_project_private_subnet.cidr_block}"]
  }
}

resource "aws_security_group" "final_project_private_security_group" {
    name = "vpc_db"
    description = "Allow incoming database connections."

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

#    ingress { # MySQL
#        from_port = 0
#        to_port = 0
#        protocol = "-1"
#        security_groups = ["${aws_security_group.final_project_public_security_group.id}"]
#    }
    vpc_id = "${aws_vpc.final_project_vpc.id}"

    tags {
        Name = "DBServerSG"
    }
}

resource "aws_instance" "k8s_slave1" {
  ami           = "ami-0f65671a86f061fcd"
  instance_type = "t2.micro"
  private_ip    = "10.0.0.102"
  key_name      = "${var.aws_key_name}"

  tags {
    Name = "k8s_slave1"
  }

  vpc_security_group_ids      = ["${aws_security_group.final_project_public_security_group.id}"]
  subnet_id                   = "${aws_subnet.final_project_public_subnet.id}"
  associate_public_ip_address = true
  source_dest_check           = false

  connection {
    user        = "ubuntu"
    type        = "ssh"
    private_key = "${file(var.aws_key_path)}"
  }

  user_data		= "${file("user_data.conf")}"
}

resource "aws_instance" "k8s_slave2" {
  ami           = "ami-0f65671a86f061fcd"
  instance_type = "t2.micro"
  private_ip    = "10.0.0.103"
  key_name      = "${var.aws_key_name}"

  tags {
    Name = "k8s_slave2"
  }

  vpc_security_group_ids      = ["${aws_security_group.final_project_public_security_group.id}"]
  subnet_id                   = "${aws_subnet.final_project_public_subnet.id}"
  associate_public_ip_address = true
  source_dest_check           = false

  connection {
    user        = "ubuntu"
    type        = "ssh"
    private_key = "${file(var.aws_key_path)}"
  }

  user_data		= "${file("user_data.conf")}"
}

resource "aws_instance" "prometheus" {
  ami           = "ami-0f65671a86f061fcd"
  instance_type = "t2.micro"
  private_ip    = "10.0.1.104"
  key_name      = "${var.aws_key_name}"

  tags {
    Name = "prometheus"
  }

  vpc_security_group_ids      = ["${aws_security_group.final_project_private_security_group.id}"]
  subnet_id                   = "${aws_subnet.final_project_private_subnet.id}"
  associate_public_ip_address = true
  source_dest_check           = false

  connection {
    user        = "ubuntu"
    type        = "ssh"
    private_key = "${file(var.aws_key_path)}"
  }

  user_data		= "${file("user_data.conf")}"
}

resource "aws_instance" "grafana" {
  ami           = "ami-0f65671a86f061fcd"
  instance_type = "t2.micro"
  private_ip    = "10.0.0.105"
  key_name      = "${var.aws_key_name}"

  tags {
    Name = "grafana"
  }

  vpc_security_group_ids      = ["${aws_security_group.final_project_public_security_group.id}"]
  subnet_id                   = "${aws_subnet.final_project_public_subnet.id}"
  associate_public_ip_address = true
  source_dest_check           = false

  connection {
    user        = "ubuntu"
    type        = "ssh"
    private_key = "${file(var.aws_key_path)}"
  }

  user_data		= "${file("user_data.conf")}"
}

resource "aws_instance" "kibana" {
  ami           = "ami-0f65671a86f061fcd"
  #instance_type = "t3.medium"
  instance_type = "t2.micro"
  private_ip    = "10.0.0.106"
  key_name      = "${var.aws_key_name}"

  tags {
    Name = "kibana"
  }

  vpc_security_group_ids      = ["${aws_security_group.final_project_public_security_group.id}"]
  subnet_id                   = "${aws_subnet.final_project_public_subnet.id}"
  associate_public_ip_address = true
  source_dest_check           = false

  connection {
    user        = "ubuntu"
    type        = "ssh"
    private_key = "${file(var.aws_key_path)}"
  }

  user_data		= "${file("user_data.conf")}"
}

resource "aws_instance" "consul1" {
  ami           = "ami-0653e888ec96eab9b"
  instance_type = "t2.micro"
  private_ip    = "10.0.1.107"
  key_name      = "${var.aws_key_name}"

  tags {
    Name = "consul1"
  }

  vpc_security_group_ids      = ["${aws_security_group.final_project_private_security_group.id}"]
  subnet_id                   = "${aws_subnet.final_project_private_subnet.id}"
  associate_public_ip_address = true
  source_dest_check           = false

  connection {
    user        = "ubuntu"
    type        = "ssh"
    private_key = "${file(var.aws_key_path)}"
  }

  user_data		= "${file("user_data.conf")}"
}

resource "aws_instance" "consul2" {
  ami           = "ami-0653e888ec96eab9b"
  instance_type = "t2.micro"
  private_ip    = "10.0.1.108"
  key_name      = "${var.aws_key_name}"

  tags {
    Name = "consul2"
  }

  vpc_security_group_ids      = ["${aws_security_group.final_project_private_security_group.id}"]
  subnet_id                   = "${aws_subnet.final_project_private_subnet.id}"
  associate_public_ip_address = true
  source_dest_check           = false

  connection {
    user        = "ubuntu"
    type        = "ssh"
    private_key = "${file(var.aws_key_path)}"
  }

  user_data		= "${file("user_data.conf")}"
}

resource "aws_instance" "consul3" {
  ami           = "ami-0653e888ec96eab9b"
  instance_type = "t2.micro"
  private_ip    = "10.0.1.109"
  key_name      = "${var.aws_key_name}"

  tags {
    Name = "consul3"
  }

  vpc_security_group_ids      = ["${aws_security_group.final_project_private_security_group.id}"]
  subnet_id                   = "${aws_subnet.final_project_private_subnet.id}"
  associate_public_ip_address = true
  source_dest_check           = false

  connection {
    user        = "ubuntu"
    type        = "ssh"
    private_key = "${file(var.aws_key_path)}"
  }

  user_data		= "${file("user_data.conf")}"
}

resource "aws_instance" "mysql_master" {
  ami           = "ami-0f65671a86f061fcd"
  instance_type = "t2.micro"
  private_ip    = "10.0.0.110"
  key_name      = "${var.aws_key_name}"

  tags {
    Name = "mysql_master"
  }

  vpc_security_group_ids      = ["${aws_security_group.final_project_public_security_group.id}"]
  subnet_id                   = "${aws_subnet.final_project_public_subnet.id}"
  associate_public_ip_address = true
  source_dest_check           = false

  connection {
    user        = "ubuntu"
    type        = "ssh"
    private_key = "${file(var.aws_key_path)}"
  }

  user_data		= "${file("user_data.conf")}"
}

resource "aws_instance" "mysql_slave" {
  ami           = "ami-0f65671a86f061fcd"
  instance_type = "t2.micro"
  private_ip    = "10.0.1.111"
  key_name      = "${var.aws_key_name}"

  tags {
    Name = "mysql_slave"
  }

  vpc_security_group_ids      = ["${aws_security_group.final_project_private_security_group.id}"]
  subnet_id                   = "${aws_subnet.final_project_private_subnet.id}"
  associate_public_ip_address = true
  source_dest_check           = false

  connection {
    user        = "ubuntu"
    type        = "ssh"
    private_key = "${file(var.aws_key_path)}"
  }

  user_data		= "${file("user_data.conf")}"
}

resource "aws_instance" "jenkins" {
  ami           = "ami-0653e888ec96eab9b"
  instance_type = "t2.micro"
  private_ip    = "10.0.0.112"
  key_name      = "${var.aws_key_name}"

  tags {
    Name = "jenkins"
  }

  vpc_security_group_ids      = ["${aws_security_group.final_project_public_security_group.id}"]
  subnet_id                   = "${aws_subnet.final_project_public_subnet.id}"
  associate_public_ip_address = true
  source_dest_check           = false

  connection {
    user        = "ubuntu"
    type        = "ssh"
    private_key = "${file(var.aws_key_path)}"
  }

  user_data		= "${file("user_data.conf")}"
}

resource "aws_instance" "icinga" {
  ami           = "ami-0653e888ec96eab9b"
  instance_type = "t2.micro"
  private_ip    = "10.0.0.113"
  key_name      = "${var.aws_key_name}"

  tags {
    Name = "icinga"
  }

  vpc_security_group_ids      = ["${aws_security_group.final_project_public_security_group.id}"]
  subnet_id                   = "${aws_subnet.final_project_public_subnet.id}"
  associate_public_ip_address = true
  source_dest_check           = false

  connection {
    user        = "ubuntu"
    type        = "ssh"
    private_key = "${file(var.aws_key_path)}"
  }

  user_data		= "${file("user_data.conf")}"
}

resource "aws_instance" "haproxy" {
  ami           = "ami-0f65671a86f061fcd"
  instance_type = "t2.micro"
  private_ip    = "10.0.0.114"
  key_name      = "${var.aws_key_name}"

  tags {
    Name = "haproxy"
  }

  vpc_security_group_ids      = ["${aws_security_group.final_project_public_security_group.id}"]
  subnet_id                   = "${aws_subnet.final_project_public_subnet.id}"
  associate_public_ip_address = true
  source_dest_check           = false

  connection {
    user        = "ubuntu"
    type        = "ssh"
    private_key = "${file(var.aws_key_path)}"
  }

  user_data		= "${file("user_data.conf")}"
}

resource "aws_instance" "k8s_master" {
  ami           = "ami-0f65671a86f061fcd"
#  instance_type = "t2.micro"
  instance_type = "t3.medium"
  private_ip    = "10.0.0.101"
  key_name      = "${var.aws_key_name}"

  tags {
    Name = "k8s_master"
  }

  vpc_security_group_ids      = ["${aws_security_group.final_project_public_security_group.id}"]
  subnet_id                   = "${aws_subnet.final_project_public_subnet.id}"
  associate_public_ip_address = true
  source_dest_check           = false
  
  depends_on = ["aws_instance.prometheus", "aws_instance.grafana", "aws_instance.kibana", "aws_instance.consul1", "aws_instance.consul2", "aws_instance.consul3", "aws_instance.mysql_master", "aws_instance.mysql_slave", "aws_instance.jenkins", "aws_instance.k8s_slave1", "aws_instance.k8s_slave2"]

  connection {
    user        = "ubuntu"
    type        = "ssh"
    private_key = "${file(var.aws_key_path)}"
  }

  user_data		= "${file("user_data_ansible.conf")}"

  provisioner "file" {
    source      = "${var.aws_key_path}"
    destination = "/home/ubuntu/.ssh/id_rsa"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 /home/ubuntu/.ssh/id_rsa",
      "git clone https://github.com/eagle-opsschool/final-project.git",
      "cd final-project/ansible",
#      "ansible-playbook site.yml",
    ]
  }
}
