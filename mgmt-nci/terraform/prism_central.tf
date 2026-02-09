# ===================================================================
# Prism Central Deployment
# ===================================================================
# Deploys Prism Central 7.5
# Note: This is an action-only resource - update/delete have no effect
# To redeploy, use: terraform destroy -target + terraform apply -target

resource "nutanix_pc_deploy_v2" "prism_central" {
  # Prism Central Configuration
  config {
    name = "PrismCentral"
    size = "LARGE"

    build_info {
      version = "pc.7.5.0.1"
    }

    credentials {
      username = var.nutanix_pe_username
      password = var.nutanix_pe_password
    }
  }

  # Network Configuration
  network {
    # DNS Servers (use LAB-DC)
    name_servers {
      ipv4 {
        value = var.nutanix_pc_name_server_ip
      }
    }

    # NTP Servers
    ntp_servers {
      fqdn {
        value = var.nutanix_ntp_server
      }
    }

    # External Network (primary subnet)
    external_networks {
      network_ext_id = nutanix_subnet.cluster_0_primary[0].id

      default_gateway {
        ipv4 {
          value = "${local.subnet_config[0].subnet_base}.1"
        }
      }

      subnet_mask {
        ipv4 {
          value = "255.255.255.128"
        }
      }

      ip_ranges {
        begin {
          ipv4 {
            value = "${local.subnet_config[0].subnet_base}.7"
          }
        }
        end {
          ipv4 {
            value = "${local.subnet_config[0].subnet_base}.7"
          }
        }
      }
    }

  }

  # Disable HA for single-node deployment
  should_enable_high_availability = false

  # Important: Increase timeout for PC deployment (can take 30-60 minutes)
  timeouts {
    create = "90m"
  }

  # Dependencies
  depends_on = [
    nutanix_subnet.cluster_0_primary,
    null_resource.ad_password_policy_cluster_0
  ]
}
