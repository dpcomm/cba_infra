variable "namespaces" {
  description = "Namespace definitions keyed by namespace name."
  type = map(object({
    labels = optional(map(string), {})
  }))
}
