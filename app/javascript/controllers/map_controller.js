import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "message"]
  static values = {
    nearbyUrl: String,
    googleMapsApiKey: String,
    permissionDenied: String,
    unsupported: String,
    notConfigured: String,
    loading: String
  }

  toggled() {
    if (!this.element.open || this.initialized) return
    this.initialized = true

    if (!this.googleMapsApiKeyValue) {
      this.messageTarget.textContent = this.notConfiguredValue
      return
    }

    if (!navigator.geolocation) {
      this.messageTarget.textContent = this.unsupportedValue
      return
    }

    this.messageTarget.textContent = this.loadingValue
    navigator.geolocation.getCurrentPosition(
      (position) => this.showMap(position.coords.latitude, position.coords.longitude),
      () => { this.messageTarget.textContent = this.permissionDeniedValue },
      { timeout: 8000 }
    )
  }

  async showMap(lat, lng) {
    await this.loadGoogleMaps()

    this.messageTarget.classList.add("hidden")
    this.containerTarget.classList.remove("hidden")

    const center = { lat, lng }
    const map = new google.maps.Map(this.containerTarget, { center, zoom: 13 })

    const response = await fetch(`${this.nearbyUrlValue}?lat=${lat}&lng=${lng}`)
    const providers = await response.json()

    // Shared across markers so only one info bubble is open at a time —
    // clicking a pin shows the provider's name first; the name itself is a
    // real link, so a second, deliberate click is what navigates away.
    const infoWindow = new google.maps.InfoWindow()

    providers.forEach((provider) => {
      const position = { lat: Number(provider.latitude), lng: Number(provider.longitude) }
      const icon = provider.logo_url
        ? { url: provider.logo_url, scaledSize: new google.maps.Size(40, 40) }
        : undefined

      const marker = new google.maps.Marker({ position, map, icon, title: provider.name })

      marker.addListener("click", () => {
        const link = document.createElement("a")
        link.href = provider.url
        link.textContent = provider.name
        link.className = "font-medium text-blue-600 hover:underline"

        infoWindow.setContent(link)
        infoWindow.open({ anchor: marker, map })
      })
    })
  }

  loadGoogleMaps() {
    if (window.google?.maps) return Promise.resolve()
    if (this.googleMapsPromise) return this.googleMapsPromise

    this.googleMapsPromise = new Promise((resolve, reject) => {
      const script = document.createElement("script")
      script.src = `https://maps.googleapis.com/maps/api/js?key=${this.googleMapsApiKeyValue}&loading=async`
      script.async = true
      script.onload = resolve
      script.onerror = reject
      document.head.appendChild(script)
    })

    return this.googleMapsPromise
  }
}
