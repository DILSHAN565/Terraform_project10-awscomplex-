output "loadbalancerdns" {
  value = aws_lb.myalb[0].dns_name
}