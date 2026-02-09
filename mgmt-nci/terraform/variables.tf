variable "nutanix_pe_username" {
    description = "Nutanix Prism username"
    type        = string
}

variable "nutanix_pe_password" {
    description = "Nutanix Prism password"
    type        = string
}

variable "nutanix_pe_endpoint" {
    description = "Nutanix Prism endpoint"
    type        = string
}

variable "nutanix_pe_port" {
    description = "Nutanix Prism port"
    type        = string
}

variable "nutanix_pc_name_server_ip" {
    description = "IP address of the DNS server for Prism Central"
    type        = string
}

variable "nutanix_ntp_server" {
    description = "FQDN or IP of the NTP server for Prism Central"
    type        = string
}