resource "nutanix_subnet" "nkp_subnet" {
  cluster_uuid = local.cluster_0_info.uuid

  name        = "${local.cluster_0_info.name}-secondary"
  vlan_id     = local.subnet_config[0].secondary_vlan_id
  subnet_type = "VLAN"

  prefix_length      = 25
  default_gateway_ip = local.subnet_config[0].secondary_gateway
  subnet_ip          = local.subnet_config[0].secondary_subnet_ip

  ip_config_pool_list_ranges   = var.enable_ipam ? ["${local.subnet_config[0].secondary_ipam_start} ${local.subnet_config[0].secondary_ipam_end}"] : []
  dhcp_domain_name_server_list = local.lab_dc_dns_server

  dhcp_options = {
    domain_name = var.domain_name
  }

  lifecycle {
    ignore_changes = [
      dhcp_options["boot_file_name"],
      dhcp_options["tftp_server_name"],
    ]
  }
}