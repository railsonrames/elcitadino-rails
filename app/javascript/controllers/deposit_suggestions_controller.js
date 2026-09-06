import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]
  static values = { price: Number }

  fill(event) {
    const { percent, amount } = event.currentTarget.dataset
    this.inputTarget.value = percent ? (this.priceValue * percent / 100).toFixed(2) : amount
  }
}
