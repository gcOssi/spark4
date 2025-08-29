# Reenviar Authorization al origin (y opcionalmente cookies + querystrings)
resource "aws_cloudfront_origin_request_policy" "forward_authz" {
  name = "${var.name_prefix}-forward-authorization"
  headers_config {
    header_behavior = "whitelist"
    headers {
      items = ["Authorization"]
    }
  }
  cookies_config {
    cookie_behavior = "all"     # Igual que tenías en forwarded_values (cookies all)
  }
  query_strings_config {
    query_string_behavior = "all"  # Igual que tenías (query_string = true)
  }
}

# Política de caché administrada: sin caché (útil con auth)
data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

# Distribución (usa policies modernas; NO mezclamos forwarded_values)
resource "aws_cloudfront_distribution" "this" {
  origin {
    domain_name = aws_lb.this.dns_name
    origin_id   = "alb-origin"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"   # El ALB está detrás; OK
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.name_prefix}-staging"
  default_root_object = "/"
  price_class         = "PriceClass_100"

  default_cache_behavior {
    target_origin_id       = "alb-origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]

    # 🔑 Policies modernas
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.forward_authz.id

    compress = true
    min_ttl  = 0
    default_ttl = 0
    max_ttl  = 0
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
