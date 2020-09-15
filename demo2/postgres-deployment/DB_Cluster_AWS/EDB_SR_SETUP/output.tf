output "Master-IP" {
value = var.vip
}
output "Slave-IP-1" {
value = aws_spot_instance_request.EDB_DB_Cluster[1].private_ip
}
output "Slave-IP-2" {
value = aws_spot_instance_request.EDB_DB_Cluster[2].private_ip
}


output "Master-PrivateIP" {
value = aws_spot_instance_request.EDB_DB_Cluster[0].private_ip
}
output "Slave-1-PrivateIP" {
value = aws_spot_instance_request.EDB_DB_Cluster[1].private_ip
}
output "Slave-2-PrivateIP" {
value = aws_spot_instance_request.EDB_DB_Cluster[2].private_ip
}

output "DBENGINE" {
value = var.dbengine
}

output "Key-Pair" {
value = var.ssh_keypair
}

output "Key-Pair-Path" {
value = var.ssh_key_path
}

output "DBUSER" {
value = var.db_user
}

output "S3BUCKET" {
value = var.s3bucket
}

output "CLUSTER_NAME" {
value = var.cluster_name
}   
