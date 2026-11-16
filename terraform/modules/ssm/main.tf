resource "aws_ssm_parameter" "search_radius_miles" {
  name  = "${var.ssm_prefix}/search-radius-miles"
  type  = "String"
  value = var.search_radius_miles

  tags = var.tags
}

resource "aws_ssm_parameter" "inactivity_ttl_seconds" {
  name  = "${var.ssm_prefix}/inactivity-ttl-seconds"
  type  = "String"
  value = var.inactivity_ttl_seconds

  tags = var.tags
}

resource "aws_ssm_parameter" "location_update_interval_seconds" {
  name  = "${var.ssm_prefix}/location-update-interval-seconds"
  type  = "String"
  value = var.location_update_interval_seconds

  tags = var.tags
}

resource "aws_ssm_parameter" "max_friends" {
  name  = "${var.ssm_prefix}/max-friends"
  type  = "String"
  value = var.max_friends

  tags = var.tags
}

resource "aws_ssm_parameter" "nearby_strangers_limit" {
  name  = "${var.ssm_prefix}/nearby-strangers-limit"
  type  = "String"
  value = var.nearby_strangers_limit

  tags = var.tags
}
