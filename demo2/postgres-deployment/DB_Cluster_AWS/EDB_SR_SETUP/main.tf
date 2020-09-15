data "aws_ami" "centos_ami" {
  most_recent = true
  owners      = ["aws-marketplace"]

  filter {
    name = "description"
    
    values = [
      "CentOS Linux 7 x86_64 HVM EBS*"
    ]
 }

  filter {
    name = "name"

    values = [
      "CentOS Linux 7 x86_64 HVM EBS *",
    ]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}



resource "aws_security_group" "edb_sg" {
    count = var.custom_security_group_id == "" ? 1 : 0 
    name = "edb_security_groupforsr"
    description = "Rule for edb-terraform-resource"
    vpc_id = var.vpc_id

    ingress {
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
    ingress {
    from_port = 5444
    to_port   = 5444
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    from_port = 7800
    to_port   = 7900
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    from_port = -1
    to_port   = -1
    protocol  = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
}


# resource "aws_instance" "EDB_DB_Cluster" {
resource "aws_spot_instance_request" "EDB_DB_Cluster" {
   count = length(var.subnet_id)
   ami = data.aws_ami.centos_ami.id
   spot_price    = var.spot_price
   wait_for_fulfillment = true
   ebs_optimized = true
   instance_type  = var.instance_type
   key_name   = var.ssh_keypair
   subnet_id = var.subnet_id[count.index]
   iam_instance_profile = var.iam-instance-profile
   vpc_security_group_ids = ["${var.custom_security_group_id == "" ? aws_security_group.edb_sg[0].id : var.custom_security_group_id}"]
root_block_device {
   delete_on_termination = "true"
   volume_size = "8"
   volume_type = "gp2"
}
  #  source_dest_check = false # doesn't work in spot instance so set the property in user_data
   user_data = <<-EOT
#!/bin/bash
cd /tmp
sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
sudo systemctl enable amazon-ssm-agent
sudo systemctl start amazon-ssm-agent

echo 'include_only=ftp.iij.ad.jp' | sudo tee -a /etc/yum/pluginconf.d/fastestmirror.conf
sudo yum clean all

sudo yum install -y NetworkManager
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager

sudo nmcli con mod "System ens5" +ipv4.addresses ${var.vip}/32
sudo nmcli con up "System ens5"
EOT

tags = {
  Name = count.index == 0 ? "${local.CLUSTER_NAME}-master" : "${local.CLUSTER_NAME}-standby${count.index}"
  Created_By = "Terraform"
}

  provisioner "local-exec" {
    command = "aws ec2 create-tags --resources ${self.spot_instance_id} --tags Key=Name,Value='${local.CLUSTER_NAME}'"
  }

  provisioner "local-exec" {
    command = "aws ec2 modify-instance-attribute --instance-id ${self.spot_instance_id} --no-source-dest-check"
  }

provisioner "local-exec" {
    command = "echo '${self.private_ip} ansible_ssh_private_key_file=${var.ssh_key_path}' >> ${path.module}/utilities/scripts/hosts"
}

provisioner "local-exec" {
    command = "sleep 60" 
}

provisioner "remote-exec" {
    inline = [
     "yum info python"
]
connection {
      host = self.private_ip 
      type = "ssh"
      user = var.ssh_user
      private_key = file(var.ssh_key_path)
    }
  }

provisioner "local-exec" {
    command = "ansible-playbook -i ${path.module}/utilities/scripts/hosts -u centos --private-key '${file(var.ssh_key_path)}' '${path.module}/utilities/scripts/install${var.dbengine}.yml' --extra-vars='USER=${var.EDB_yumrepo_username} PASS=${var.EDB_yumrepo_password} PGDBUSER=${local.DBUSERPG}  EPASDBUSER=${local.DBUSEREPAS}' --limit ${self.private_ip}" 
}

lifecycle {
    create_before_destroy = true
  }

}

# resource "aws_eip" "master-ip" {
#     instance = aws_instance.EDB_DB_Cluster[0].id
#     vpc      = true

# depends_on = [aws_instance.EDB_DB_Cluster[0]]

# provisioner "local-exec" {
#     command = "echo '${aws_eip.master-ip.public_ip} ansible_ssh_private_key_file=${var.ssh_key_path}' >> ${path.module}/utilities/scripts/hosts"
# }
# }

resource "aws_route" "vip" {
  route_table_id         = var.route_table_id
  instance_id = aws_spot_instance_request.EDB_DB_Cluster[0].spot_instance_id
  destination_cidr_block = "${var.vip}/32"
}


locals {
  DBUSERPG="${var.db_user == "" || var.dbengine == regexall("${var.dbengine}", "pg10 pg11 pg12") ? "postgres" : var.db_user}" 
  DBUSEREPAS="${var.db_user == "" || var.dbengine == regexall("${var.dbengine}", "epas10 eaps11 epas12") ? "enterprisedb" : var.db_user}"
  DBPASS="${var.db_password == "" ? "postgres" : var.db_password}"
  # REGION="${substr("${aws_spot_instance_request.EDB_DB_Cluster[0].availability_zone}", 0, 9)}"
  CLUSTER_NAME="${var.cluster_name == "" ? var.dbengine : var.cluster_name}"
}

#####################################
## Configuration of streaming replication start here
#
#
########################################### 


resource "null_resource" "configuremaster" {
  # Define the trigger condition to run the resource block
  triggers = {
    cluster_instance_ids = "${join(",", aws_spot_instance_request.EDB_DB_Cluster.*.spot_instance_id)}"
  }

depends_on = [aws_spot_instance_request.EDB_DB_Cluster[0]]



provisioner "local-exec" {
   command = "ansible-playbook -i ${path.module}/utilities/scripts/hosts -u centos --private-key '${file(var.ssh_key_path)}' '${path.module}/utilities/scripts/configuremaster.yml' --extra-vars='ip1=${aws_spot_instance_request.EDB_DB_Cluster[1].private_ip} ip2=${aws_spot_instance_request.EDB_DB_Cluster[2].private_ip} ip3=${aws_spot_instance_request.EDB_DB_Cluster[0].private_ip} REPLICATION_USER_PASSWORD=${var.replication_password} DB_ENGINE=${var.dbengine} PGDBUSER=${local.DBUSERPG}  EPASDBUSER=${local.DBUSEREPAS} REPLICATION_TYPE=${var.replication_type} DBPASSWORD=${local.DBPASS} S3BUCKET=${var.s3bucket}' --limit ${aws_spot_instance_request.EDB_DB_Cluster[0].private_ip}"

}

}

resource "null_resource" "configureslave1" {
  # Define the trigger condition to run the resource block
  triggers = {
    cluster_instance_ids = "${join(",", aws_spot_instance_request.EDB_DB_Cluster.*.spot_instance_id)}"
  }

depends_on = [null_resource.configuremaster]

provisioner "local-exec" {
   command = "ansible-playbook -i ${path.module}/utilities/scripts/hosts -u centos --private-key '${file(var.ssh_key_path)}' '${path.module}/utilities/scripts/configureslave.yml' --extra-vars='ip1=${aws_spot_instance_request.EDB_DB_Cluster[0].private_ip} ip2=${aws_spot_instance_request.EDB_DB_Cluster[2].private_ip} REPLICATION_USER_PASSWORD=${var.replication_password} DB_ENGINE=${var.dbengine} REPLICATION_TYPE=${var.replication_type} SLAVE1=${aws_spot_instance_request.EDB_DB_Cluster[1].private_ip} SLAVE2=${aws_spot_instance_request.EDB_DB_Cluster[2].private_ip} MASTER=${aws_spot_instance_request.EDB_DB_Cluster[0].private_ip} S3BUCKET=${var.s3bucket}' --limit ${aws_spot_instance_request.EDB_DB_Cluster[1].private_ip},${aws_spot_instance_request.EDB_DB_Cluster[0].private_ip}"

}

}

resource "null_resource" "configureslave2" {
  # Define the trigger condition to run the resource block
  triggers = {
    cluster_instance_ids = "${join(",", aws_spot_instance_request.EDB_DB_Cluster.*.spot_instance_id)}"
  }

depends_on = [null_resource.configuremaster]

provisioner "local-exec" {
   command = "ansible-playbook -i ${path.module}/utilities/scripts/hosts -u centos --private-key '${file(var.ssh_key_path)}' '${path.module}/utilities/scripts/configureslave.yml' --extra-vars='ip1=${aws_spot_instance_request.EDB_DB_Cluster[0].private_ip} ip2=${aws_spot_instance_request.EDB_DB_Cluster[1].private_ip} REPLICATION_USER_PASSWORD=${var.replication_password} DB_ENGINE=${var.dbengine} REPLICATION_TYPE=${var.replication_type} SLAVE2=${aws_spot_instance_request.EDB_DB_Cluster[2].private_ip} SLAVE1=${aws_spot_instance_request.EDB_DB_Cluster[1].private_ip} MASTER=${aws_spot_instance_request.EDB_DB_Cluster[0].private_ip} S3BUCKET=${var.s3bucket}' --limit ${aws_spot_instance_request.EDB_DB_Cluster[2].private_ip},${aws_spot_instance_request.EDB_DB_Cluster[0].private_ip}"

}

}


resource "null_resource" "removehostfile" {

provisioner "local-exec" {
  command = "rm -rf ${path.module}/utilities/scripts/hosts"
}

depends_on = [
      null_resource.configureslave2,
      null_resource.configureslave1,
      null_resource.configuremaster,
      aws_spot_instance_request.EDB_DB_Cluster
]
}
