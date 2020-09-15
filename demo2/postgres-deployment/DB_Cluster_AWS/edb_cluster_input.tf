###### Mandatory Fields in this config file #####

### region_name
### instance_type
### ssh_keypair   
### ssh_key_path
### subnet_id
### vpc_id 
### replication_password
### s3bucket
#############################################

### Optional Field in this config file

### EDB_yumrepo_username } Mandatory if selecting dbengine epas(all version) 
### EDB_yumrepo_password }
### iam-instance-profile
### custom_security_group_id
### replication_type } by default asynchronous
### db_user
### db_password
### cluster_name
###########################################

### Default User DB credentials##########

## You can change this any time

### For PG10, PG11, PG12
## Username: postgres
## Password: postgres

### For EPAS10, EPAS11, EPAS12
## Username: enterprisedb
## Password: postgres

########################################

variable "region_name" {
   description = "AWS Region Code like us-east-1,us-west-1"
   type = string
   default = "ap-northeast-1"
}


provider "aws" {
  region     = var.region_name
}


module "edb-db-cluster" {
  # The source module used for creating AWS clusters.
 
  source = "./EDB_SR_SETUP"
  
  # Enter EDB Yum Repository Credentials for usage of any EDB tools.

  EDB_yumrepo_username = "kotaroyoshino"

  # Enter EDB Yum Repository Credentials for usage of any EDB tools.

  EDB_yumrepo_password = "★★ パスワードは削除 ★★"

  # Provide cluster name. Leaving this field blank will tag cluster with dbengine name.

  cluster_name = "demo2"

  # Enter this mandatory field which is VPC ID

  vpc_id = "vpc-08033fc29ee7a8d1e"

  # Enter subnet ID where instance going to create in format ["subnetid1","subnetid2", "subnetid3"]

  subnet_id = ["subnet-0b9c0d8aa790bd792", "subnet-0de08d25e19403f0f", "subnet-0eb64baf539f09971"]

  spot_price = "0.08"

  # Enter AWS Instance type like t2.micro, t3.large, c4.2xlarge m5.2xlarge etc....
 
  instance_type = "t3.large"
  
  # Enter IAM Role Name to be attached to instance. Leave blank if you are providing AWS credentials.

  iam-instance-profile = "edb-ec2-failover-role"
 
  # Enter AWS VPC Security Group ID. If left blank new security group will create and attached to newly created instance ...
   
  custom_security_group_id = ""

  # Provide s3 bucket name followed by folder name for wal archive. Eg. s3bucket=bucketname/foldername

  s3bucket = "edb-data-webinar-202009-demo/demo2"

  # Enter SSH key pair name. You must create this before running this terraform config file
 
  ssh_keypair = "key-demo2"

  # Provide path of ssh private file downloaded on your local system.

  ssh_key_path = "/home/ec2-user/postgres-deployment/key-demo2.pem"

  # Select database engine(DB) version like pg10-postgresql version10, epas12-Enterprise Postgresql Advanced server etc..
  # DB version support V10-V12

  dbengine = "pg12"

  # Enter optional database (DB) User, leave it blank to use default user else enter desired user. 
  
  db_user = ""

  # Enter custom database DB password. By default it is "postgres"

  db_password = ""
  
  # Enter replication type(synchronous or asynchronous). Leave it blank to use default replication type "asynchronous".

  replication_type = ""
  
  # Enter replication user password

  replication_password = "rep-password"

  # Enter route table ID of private subnet

  route_table_id = "rtb-04c3ac591c637c71e"

  # vip

  vip = "10.10.0.1"
}  

output "Master-PublicIP" {
  value = "${module.edb-db-cluster.Master-IP}"
}

output "Standby1-PublicIP" {
  value = "${module.edb-db-cluster.Slave-IP-1}"
}

output "Standby2-PublicIP" {
  value = "${module.edb-db-cluster.Slave-IP-2}"
}

output "Master-PrivateIP" {
   value = "${module.edb-db-cluster.Master-PrivateIP}"
}

output "Standby1-PrivateIP" {
  value = "${module.edb-db-cluster.Slave-1-PrivateIP}"
}

output "Standby2-PrivateIP" {
  value = "${module.edb-db-cluster.Slave-2-PrivateIP}"
}

output "Region" {
  value = "${var.region_name}" 
}

output "DBENGINE" {
  value = "${module.edb-db-cluster.DBENGINE}"
}

output "Key-Pair" {
  value = "${module.edb-db-cluster.Key-Pair}"
}

output "Key-Pair-Path" {
  value = "${module.edb-db-cluster.Key-Pair-Path}"
}

output "S3BUCKET" {
  value = "${module.edb-db-cluster.S3BUCKET}"
}

output "CLUSTER_NAME" {
  value = "${module.edb-db-cluster.CLUSTER_NAME}"
}
