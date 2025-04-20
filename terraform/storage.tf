resource "google_compute_disk" "aosp_mirror_disk" {
  name = "aosp-mirror-disk"
  type = "pd-standard"
  size = 2000
  zone  = "${var.region}-a"
}