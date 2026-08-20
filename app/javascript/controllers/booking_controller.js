import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["scheduledAt", "submit", "slotButton"]

  selectSlot(event) {
    this.scheduledAtTarget.value = event.currentTarget.dataset.bookingTimeParam
    this.submitTarget.disabled = false

    this.slotButtonTargets.forEach((button) => {
      button.classList.toggle("bg-blue-600", button === event.currentTarget)
      button.classList.toggle("text-white", button === event.currentTarget)
      button.classList.toggle("border-blue-600", button === event.currentTarget)
    })
  }
}
