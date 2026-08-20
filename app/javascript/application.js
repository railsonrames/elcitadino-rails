// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

const swPath = document.querySelector('meta[name="service-worker-path"]')?.content
if ("serviceWorker" in navigator && swPath) {
  window.addEventListener("load", () => navigator.serviceWorker.register(swPath))
}
