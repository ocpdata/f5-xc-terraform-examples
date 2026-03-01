resource "kubernetes_namespace" "aks_namespace" {
  count = local.create_aks_namespace ? 1 : 0

  provider = kubernetes.aks

  metadata {
    annotations = {
      name = local.namespace
    }
    name = local.namespace
  }
}

# ── Custom Details App – queries Open Library API ────────────────────────────
resource "kubernetes_config_map" "details_code" {
  provider = kubernetes.aks

  metadata {
    name      = "details-code"
    namespace = local.aks_namespace
  }

  data = {
    "app.py" = <<-PYTHON
    import os, requests
    from flask import Flask, jsonify

    app = Flask(__name__)

    CATALOG = {
        "1": "9780140449136",
        "2": "9780743273565",
        "3": "9780061965548",
        "4": "9780451524935",
        "5": "9780316769174",
    }

    def fetch(isbn):
        key = "ISBN:" + isbn
        url = ("https://openlibrary.org/api/books"
               "?bibkeys=" + key + "&format=json&jscmd=data")
        return requests.get(url, timeout=8).json().get(key, {})

    @app.route("/details/<book_id>")
    def details(book_id):
        isbn = CATALOG.get(str(book_id), CATALOG["1"])
        try:
            d = fetch(isbn)
            authors = [a.get("name", "Unknown") for a in d.get("authors", [])]
            raw_desc = d.get("description", "")
            desc = (raw_desc.get("value", "") if isinstance(raw_desc, dict)
                    else str(raw_desc))
            subjects = [(s.get("name", s) if isinstance(s, dict) else s)
                        for s in d.get("subjects", [])][:8]
            pubs  = d.get("publishers") or [{"name": "N/A"}]
            langs = d.get("languages")  or [{"key": "/languages/eng"}]
            return jsonify({
                "id": int(book_id), "isbn": isbn,
                "title":     d.get("title", "Unknown Title"),
                "author":    ", ".join(authors) or "Unknown",
                "year":      d.get("publish_date", "N/A"),
                "pages":     d.get("number_of_pages", "N/A"),
                "publisher": pubs[0].get("name", "N/A"),
                "language":  langs[0].get("key", "").replace("/languages/", ""),
                "subjects":  subjects,
                "description": desc[:600] if desc else "No description available.",
                "cover_large":  "https://covers.openlibrary.org/b/isbn/" + isbn + "-L.jpg",
                "cover_medium": "https://covers.openlibrary.org/b/isbn/" + isbn + "-M.jpg",
                "openlibrary_url": d.get("url", "https://openlibrary.org/isbn/" + isbn),
                "cloud": "Azure AKS (centralus)", "service": "details-v2",
            })
        except Exception as e:
            return jsonify({"error": str(e), "id": int(book_id)}), 500

    @app.route("/health")
    def health():
        return jsonify({"status": "ok", "service": "details", "cloud": "Azure AKS"})

    if __name__ == "__main__":
        app.run(host="0.0.0.0", port=9080)
    PYTHON
  }
}

resource "kubernetes_service_account" "bookinfo_details" {
  provider = kubernetes.aks

  metadata {
    name      = "bookinfo-details"
    namespace = local.aks_namespace
    labels = {
      account = "details"
    }
  }
}

resource "kubernetes_deployment" "bookinfo_details" {
  provider = kubernetes.aks

  metadata {
    name      = "details-v1"
    namespace = local.aks_namespace
    labels = {
      app     = "details"
      version = "v1"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app     = "details"
        version = "v1"
      }
    }
    template {
      metadata {
        labels = {
          app     = "details"
          version = "v1"
        }
      }
      spec {
        service_account_name = "bookinfo-details"

        container {
          name              = "details"
          image             = "python:3.11-slim"
          image_pull_policy = "IfNotPresent"

          command = ["/bin/sh", "-c"]
          args    = ["pip install flask requests --quiet --no-cache-dir && python /app/app.py"]

          port {
            container_port = 9080
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 9080
            }
            initial_delay_seconds = 35
            period_seconds        = 10
            failure_threshold     = 6
          }

          volume_mount {
            name       = "app-code"
            mount_path = "/app"
          }
        }

        volume {
          name = "app-code"
          config_map {
            name = kubernetes_config_map.details_code.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "bookinfo_details" {
  provider = kubernetes.aks

  metadata {
    name      = "details"
    namespace = local.aks_namespace
    labels = {
      app     = "details"
      service = "details"
    }
  }
  spec {
    type = "NodePort"
    port {
      name      = "http"
      port      = 9080
      node_port = 31002
    }
    selector = {
      app = "details"
    }
  }
}
