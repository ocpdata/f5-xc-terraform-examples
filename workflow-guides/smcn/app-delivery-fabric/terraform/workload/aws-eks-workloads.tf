resource "kubernetes_namespace" "eks_namespace" {
  count = local.create_eks_namespace ? 1 : 0

  provider = kubernetes.eks

  metadata {
    annotations = {
      name = local.namespace
    }
    name = local.namespace
  }
}

resource "kubernetes_config_map_v1_data" "coredns_eks" {
  provider = kubernetes.eks

  metadata {
    name = "coredns"
    namespace = "kube-system"
  }
  force = true

  data = tomap({"Corefile" = <<-EOT
    .:53 {
        errors
        health {
          lameduck 5s
        }
        ready
        hosts {
          ${local.aws_xc_node_inside_ip} ${local.details_domain}
          fallthrough
        }
        kubernetes cluster.local in-addr.arpa ip6.arpa {
          pods insecure
          fallthrough in-addr.arpa ip6.arpa
        }
        prometheus :9153
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
    EOT
  })
}

resource "kubernetes_service_account" "bookinfo_product" {
  provider = kubernetes.eks

  metadata {
    name      = "bookinfo-productpage"
    namespace = local.eks_namespace
    labels = {
      account = "productpage"
    }
  }
}

# ── Custom Productpage App – Graphical UI + Open Library ──────────────────────
resource "kubernetes_config_map" "productpage_code" {
  provider = kubernetes.eks

  metadata {
    name      = "productpage-code"
    namespace = local.eks_namespace
  }

  data = {
    "app.py" = <<-PYTHON
    import os, requests
    from flask import Flask, request, render_template_string, jsonify

    app = Flask(__name__)

    DETAILS_HOST = os.environ.get("DETAILS_HOSTNAME", "localhost")
    DETAILS_PORT = os.environ.get("DETAILS_SERVICE_PORT", "80")

    BOOKS = [
        {"id": "1", "name": "The Odyssey",             "isbn": "9780140449136"},
        {"id": "2", "name": "The Great Gatsby",         "isbn": "9780743273565"},
        {"id": "3", "name": "To Kill a Mockingbird",    "isbn": "9780061965548"},
        {"id": "4", "name": "1984",                     "isbn": "9780451524935"},
        {"id": "5", "name": "The Catcher in the Rye",   "isbn": "9780316769174"},
    ]

    HTML = """<!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width,initial-scale=1">
      <title>Bookinfo \u2014 {{ details.title or 'Bookinfo' }}</title>
      <style>
        *,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
        :root{
          --bg:#0d1117;--surface:#161b22;--border:#30363d;
          --text:#c9d1d9;--muted:#8b949e;
          --red:#e4002b;--blue:#388bfd;--green:#3fb950;
        }
        body{background:var(--bg);color:var(--text);
          font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;
          font-size:14px;min-height:100vh;display:flex;flex-direction:column}
        a{color:var(--blue);text-decoration:none}
        nav{background:var(--surface);border-bottom:1px solid var(--border);
          padding:0 24px;height:54px;display:flex;align-items:center;gap:12px;
          position:sticky;top:0;z-index:10}
        .logo{display:flex;align-items:center;gap:8px;font-weight:700;font-size:15px}
        .logo-dot{width:11px;height:11px;border-radius:50%;background:var(--red)}
        .badges{margin-left:auto;display:flex;gap:6px;align-items:center}
        .badge{padding:2px 9px;border-radius:20px;font-size:11px;font-weight:600;
          border:1px solid;letter-spacing:.3px}
        .b-aws{background:#1a2332;border-color:#f90;color:#f90}
        .b-xc{background:#2a0d11;border-color:var(--red);color:var(--red)}
        .b-azure{background:#0d1f35;border-color:var(--blue);color:var(--blue)}
        .b-ol{background:#1a2e1a;border-color:var(--green);color:var(--green)}
        .wrapper{display:grid;grid-template-columns:220px 1fr 260px;flex:1;
          height:calc(100vh - 54px - 40px);overflow:hidden}
        .sidebar{background:var(--surface);border-right:1px solid var(--border);
          padding:16px 0;overflow-y:auto}
        .sidebar-title{padding:0 16px 10px;font-size:11px;font-weight:600;
          letter-spacing:.8px;text-transform:uppercase;color:var(--muted)}
        .book-item{display:flex;align-items:center;gap:10px;padding:8px 14px;
          border-left:3px solid transparent;transition:background .15s}
        .book-item:hover{background:rgba(56,139,253,.07)}
        .book-item.active{background:rgba(56,139,253,.12);border-left-color:var(--blue)}
        .book-thumb{width:34px;height:46px;object-fit:cover;border-radius:3px;
          border:1px solid var(--border);background:var(--bg);flex-shrink:0}
        .book-item span{font-size:12px;line-height:1.4}
        .main{padding:24px 28px;overflow-y:auto}
        .err{background:rgba(228,0,43,.08);border:1px solid rgba(228,0,43,.3);
          border-radius:8px;padding:12px 16px;margin-bottom:18px;
          color:#f85149;font-size:13px}
        .book-header{display:flex;gap:24px;margin-bottom:22px}
        .cover-wrap{flex-shrink:0;position:relative;width:170px}
        .cover-img{width:170px;border-radius:8px;
          box-shadow:0 8px 28px rgba(0,0,0,.65);border:1px solid var(--border);display:block}
        .cover-tag{position:absolute;bottom:-9px;left:50%;transform:translateX(-50%);
          background:var(--green);color:#000;font-size:10px;font-weight:700;
          padding:2px 8px;border-radius:10px;white-space:nowrap}
        .book-info{flex:1;min-width:0}
        .book-title{font-size:24px;font-weight:700;line-height:1.25;color:#fff;margin-bottom:4px}
        .book-author{font-size:15px;color:var(--muted);margin-bottom:14px}
        .ol-btn{display:inline-flex;align-items:center;gap:5px;font-size:12px;
          color:var(--green);border:1px solid rgba(63,185,80,.3);border-radius:6px;
          padding:4px 10px;margin-bottom:14px;transition:background .15s}
        .ol-btn:hover{background:rgba(63,185,80,.1);text-decoration:none}
        .desc{font-size:13px;line-height:1.7;border-left:3px solid var(--border);
          padding-left:12px;margin-bottom:14px}
        .subjects{display:flex;flex-wrap:wrap;gap:5px;margin-bottom:16px}
        .tag{padding:3px 9px;border:1px solid var(--border);
          border-radius:20px;font-size:11px;color:var(--muted)}
        .svc{display:inline-flex;align-items:center;gap:6px;font-size:12px;
          color:var(--green);background:rgba(63,185,80,.07);
          border:1px solid rgba(63,185,80,.2);border-radius:6px;padding:5px 11px}
        .live{width:6px;height:6px;border-radius:50%;background:var(--green)}
        hr.div{border:none;border-top:1px solid var(--border);margin:16px 0 14px}
        .sec{font-size:11px;font-weight:600;text-transform:uppercase;
          letter-spacing:.8px;color:var(--muted);margin-bottom:10px}
        .meta-grid{display:grid;grid-template-columns:1fr 1fr;gap:8px}
        .mc{background:var(--bg);border:1px solid var(--border);border-radius:8px;
          padding:9px 12px;display:flex;align-items:center;gap:10px}
        .mi{font-size:17px;flex-shrink:0}
        .ml{font-size:10px;color:var(--muted);text-transform:uppercase;letter-spacing:.5px}
        .mv{font-size:13px;font-weight:600;margin-top:2px}
        .mc.s2{grid-column:span 2}
        .arch{border-left:1px solid var(--border);padding:20px 16px;overflow-y:auto}
        .at{font-size:11px;font-weight:600;text-transform:uppercase;
          letter-spacing:.8px;color:var(--muted);margin-bottom:14px}
        .adiag{display:flex;flex-direction:column;align-items:center;gap:4px;margin-bottom:14px}
        .an{width:100%;border:1px solid var(--border);border-radius:8px;
          padding:7px 10px;text-align:center;font-size:12px;font-weight:600;line-height:1.3}
        .an small{display:block;font-size:10px;font-weight:400;opacity:.75;margin-top:1px}
        .an.cl{border-color:var(--muted);color:var(--muted)}
        .an.xc{border-color:var(--red);color:var(--red);background:rgba(228,0,43,.05)}
        .an.aw{border-color:#f90;color:#f90;background:rgba(255,153,0,.05)}
        .an.az{border-color:var(--blue);color:var(--blue);background:rgba(56,139,253,.05)}
        .an.ol{border-color:var(--green);color:var(--green);background:rgba(63,185,80,.05)}
        .ar{color:var(--muted);font-size:14px;line-height:1}
        .ai{background:var(--bg);border:1px solid var(--border);
          border-radius:8px;padding:12px;font-size:12px}
        .air{display:flex;justify-content:space-between;padding:4px 0;
          border-bottom:1px solid var(--border)}
        .air:last-child{border-bottom:none}
        .aik{color:var(--muted)}
        .aiv{font-weight:600}
        .empty{text-align:center;padding:60px 20px;color:var(--muted)}
        footer{background:var(--surface);border-top:1px solid var(--border);
          padding:10px 24px;display:flex;gap:10px;font-size:12px;color:var(--muted)}
        .sep{color:var(--border)}
      </style>
    </head>
    <body>
    <nav>
      <div class="logo"><div class="logo-dot"></div>F5 XC &mdash; Bookinfo</div>
      <div class="badges">
        <span class="badge b-aws">&#9729; AWS EKS</span>
        <span style="color:var(--muted);font-size:12px;">&#8644;</span>
        <span class="badge b-xc">&#9733; XC MCN</span>
        <span style="color:var(--muted);font-size:12px;">&#8644;</span>
        <span class="badge b-azure">&#9729; Azure AKS</span>
        <span class="badge b-ol" style="margin-left:6px;">&#128218; Open Library</span>
      </div>
    </nav>
    <div class="wrapper">
      <aside class="sidebar">
        <div class="sidebar-title">&#128218; Catalog</div>
        {% for book in books %}
        <a href="/productpage?book={{ book.id }}" style="text-decoration:none">
          <div class="book-item {{ 'active' if selected == book.id else '' }}">
            <img class="book-thumb"
              src="https://covers.openlibrary.org/b/isbn/{{ book.isbn }}-S.jpg"
              alt="{{ book.name }}"
              onerror="this.style.display='none'">
            <span>{{ book.name }}</span>
          </div>
        </a>
        {% endfor %}
      </aside>
      <main class="main">
        {% if error %}
        <div class="err">&#9888; Details service unreachable: {{ error }}</div>
        {% endif %}
        {% if details.title %}
        <div class="book-header">
          <div class="cover-wrap">
            <img class="cover-img"
              src="{{ details.cover_large }}"
              alt="{{ details.title }}"
              onerror="this.src='{{ details.cover_medium }}'">
            <div class="cover-tag">Open Library</div>
          </div>
          <div class="book-info">
            <div class="book-title">{{ details.title }}</div>
            <div class="book-author">by {{ details.author }}</div>
            <a class="ol-btn" href="{{ details.openlibrary_url }}" target="_blank">
              &#128279; View on Open Library
            </a>
            {% if details.description %}
            <p class="desc">{{ details.description }}</p>
            {% endif %}
            {% if details.subjects %}
            <div class="subjects">
              {% for s in details.subjects %}<span class="tag">{{ s }}</span>{% endfor %}
            </div>
            {% endif %}
            <div class="svc"><div class="live"></div>Details from {{ details.cloud }}</div>
          </div>
        </div>
        <hr class="div">
        <div class="sec">Book Metadata</div>
        <div class="meta-grid">
          <div class="mc"><span class="mi">&#128197;</span>
            <div><div class="ml">Published</div>
                 <div class="mv">{{ details.year or 'N/A' }}</div></div></div>
          <div class="mc"><span class="mi">&#128196;</span>
            <div><div class="ml">Pages</div>
                 <div class="mv">{{ details.pages or 'N/A' }}</div></div></div>
          <div class="mc"><span class="mi">&#127970;</span>
            <div><div class="ml">Publisher</div>
                 <div class="mv">{{ details.publisher or 'N/A' }}</div></div></div>
          <div class="mc"><span class="mi">&#127760;</span>
            <div><div class="ml">Language</div>
                 <div class="mv">{{ (details.language or 'N/A')|upper }}</div></div></div>
          <div class="mc s2"><span class="mi">&#128273;</span>
            <div><div class="ml">ISBN</div>
                 <div class="mv" style="font-family:monospace;letter-spacing:.5px">
                   {{ details.isbn }}</div></div></div>
        </div>
        {% else %}
        <div class="empty">
          <div style="font-size:48px;margin-bottom:14px">&#128218;</div>
          <div style="font-size:18px;font-weight:600;color:var(--text);margin-bottom:8px">
            Select a book from the catalog</div>
          <div>Choose a title on the left to load its details from Azure AKS via XC</div>
        </div>
        {% endif %}
      </main>
      <aside class="arch">
        <div class="at">&#9883; Architecture</div>
        <div class="adiag">
          <div class="an cl">&#128100; Client Browser</div>
          <div class="ar">&#8595;</div>
          <div class="an xc">&#9733; F5 XC HTTP LB<small>WAF &bull; MCN Fabric</small></div>
          <div class="ar">&#8595;</div>
          <div class="an aw">&#9729; productpage<small>AWS EKS &bull; us-east-1</small></div>
          <div class="ar" style="font-size:11px">&#8595; XC LB internal &#8595;</div>
          <div class="an xc">&#9733; XC Inside LB<small>CoreDNS &#8594; XC IP</small></div>
          <div class="ar">&#8595;</div>
          <div class="an az">&#9729; details<small>Azure AKS &bull; centralus</small></div>
          <div class="ar">&#8595;</div>
          <div class="an ol">&#128218; Open Library API<small>openlibrary.org</small></div>
        </div>
        <div class="ai">
          <div class="air"><span class="aik">productpage</span>
            <span class="aiv" style="color:#f90">AWS EKS</span></div>
          <div class="air"><span class="aik">details</span>
            <span class="aiv" style="color:var(--blue)">Azure AKS</span></div>
          <div class="air"><span class="aik">book data</span>
            <span class="aiv" style="color:var(--green)">Open Library</span></div>
          <div class="air"><span class="aik">WAF + LB</span>
            <span class="aiv" style="color:var(--red)">F5 XC</span></div>
          <div class="air"><span class="aik">details host</span>
            <span class="aiv" style="font-size:10px;font-family:monospace">{{ details_host }}</span></div>
        </div>
      </aside>
    </div>
    <footer>
      <span>Powered by <strong style="color:var(--red)">F5 Distributed Cloud</strong></span>
      <span class="sep">|</span>
      <span>Data from <a href="https://openlibrary.org" target="_blank"
        style="color:var(--green)">Open Library API</a></span>
      <span class="sep">|</span>
      <span>Covers &copy; Open Library contributors</span>
    </footer>
    </body>
    </html>"""

    @app.route("/")
    @app.route("/productpage")
    def productpage():
        book_id = request.args.get("book", "1")
        details = {}
        error   = None
        try:
            url = ("http://" + DETAILS_HOST + ":" + DETAILS_PORT
                   + "/details/" + book_id)
            r = requests.get(url, timeout=6)
            r.raise_for_status()
            details = r.json()
        except Exception as e:
            error = str(e)
        return render_template_string(
            HTML,
            books=BOOKS,
            details=details,
            error=error,
            selected=book_id,
            details_host=DETAILS_HOST,
        )

    @app.route("/health")
    def health():
        return jsonify({"status": "ok", "service": "productpage", "cloud": "AWS EKS"})

    if __name__ == "__main__":
        app.run(host="0.0.0.0", port=9080)
    PYTHON
  }
}

resource "kubernetes_deployment" "bookinfo_product" {
  provider = kubernetes.eks

  metadata {
    name      = "productpage-v1"
    namespace = local.eks_namespace
    labels = {
      app     = "productpage"
      version = "v1"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app     = "productpage"
        version = "v1"
      }
    }
    template {
      metadata {
        labels = {
          app     = "productpage"
          version = "v1"
        }
      }
      spec {
        service_account_name = "bookinfo-productpage"

        container {
          name              = "productpage"
          image             = "python:3.11-slim"
          image_pull_policy = "IfNotPresent"

          command = ["/bin/sh", "-c"]
          args    = ["pip install flask requests --quiet --no-cache-dir && python /app/app.py"]

          port {
            container_port = 9080
          }

          env {
            name  = "DETAILS_HOSTNAME"
            value = local.details_domain
          }

          env {
            name  = "DETAILS_SERVICE_PORT"
            value = "80"
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
            name = kubernetes_config_map.productpage_code.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "bookinfo_product" {
  provider = kubernetes.eks

  metadata {
    name      = "productpage"
    namespace = local.eks_namespace
    labels = {
      app     = "productpage"
      service = "productpage"
    }
  }
  spec {
    type = "NodePort"
    port {
      name      = "http"
      port      = 9080
      node_port = 31001
    }
    selector = {
      app = "productpage"
    }
  }
}
