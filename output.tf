output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}

output "target_group_arn" {
  value = aws_lb_target_group.tg.arn
}

output "autoscaling_group_name" {
  value = aws_autoscaling_group.asg.name
}