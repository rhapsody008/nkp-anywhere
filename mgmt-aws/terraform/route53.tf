data "aws_route53_zone" "mydns" {
  name         = "yoloz.cloud"
  private_zone = false
}

resource "aws_route53_record" "nkp-bastion" {
  zone_id = data.aws_route53_zone.mydns.zone_id
  name    = "bastion.yoloz.cloud"
  type    = "A"
  ttl     = 300
  records = [aws_instance.bastion.public_ip]
}

