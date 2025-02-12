variable "EDB_Yum_Repo_Username" {
   description = "Enter EDB yum repo login user name"
   default     = ""
   type = string
   
}

variable "EDB_Yum_Repo_Password" {
   description = "Enter EDB yum repo login password"
   default     = ""
   type = string
}


variable "notification_email_address" {
   description = "Enter email address where EFM notification will go"
   type = string
}

variable "efm_role_password" {
   description = "Enter password for DB role created from EFM operation"
   type        = string
}

variable "db_user" {
   description = "Provide DB user if not using default one"
   type = string
} 

variable "route_table_id" {
   description = "route table id of private subnet"
   type = string
}

variable "bastion_ip" {
   description = "private ip of bastion"
   type = string
}
