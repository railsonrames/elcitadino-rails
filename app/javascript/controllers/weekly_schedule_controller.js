import { Controller } from "@hotwired/stimulus"

const DEFAULT_START = "09:00"
const DEFAULT_END = "18:00"
const WEEKDAYS = ["1", "2", "3", "4", "5"]
const WEEKDAYS_SATURDAY = ["1", "2", "3", "4", "5", "6"]
const ALL_WEEK = ["0", "1", "2", "3", "4", "5", "6"]

export default class extends Controller {
  static targets = ["grid", "dialog", "repeatRange", "dayCheckbox", "dayCheckboxWrapper"]

  connect() {
    this.triggered = false
  }

  // Prompts once, the first time a row gets both its start and end filled —
  // a later edit to any other row (or a second edit to this one) never
  // re-prompts, so it stays a one-time convenience, not a nag.
  fieldChanged(event) {
    if (this.triggered) return

    const row = event.target.closest("[data-day]")
    const [start, end] = this.rowTimes(row)
    if (!start || !end) return

    this.triggered = true
    this.openRepeatModal(row.dataset.day, start, end)
  }

  openRepeatModal(sourceDay, start, end) {
    this.sourceDay = sourceDay
    this.sourceStart = start
    this.sourceEnd = end
    this.repeatRangeTarget.textContent = `${start}–${end}`

    this.dayCheckboxWrapperTargets.forEach((wrapper) => {
      wrapper.classList.toggle("hidden", wrapper.dataset.checkboxDay === sourceDay)
    })

    this.dialogTarget.showModal()
  }

  apply() {
    this.dayCheckboxTargets
      .filter((checkbox) => checkbox.checked && checkbox.value !== this.sourceDay)
      .forEach((checkbox) => this.fillDay(checkbox.value, this.sourceStart, this.sourceEnd))

    this.dialogTarget.close()
  }

  skip() {
    this.dialogTarget.close()
  }

  presetWeekdays() {
    this.applyPreset(WEEKDAYS)
  }

  presetWeekdaysSaturday() {
    this.applyPreset(WEEKDAYS_SATURDAY)
  }

  presetAllWeek() {
    this.applyPreset(ALL_WEEK)
  }

  applyPreset(days) {
    const [start, end] = this.presetSourceTimes()
    days.forEach((day) => this.fillDay(day, start, end))
  }

  // Reuses whatever's already typed into any row as the preset's time
  // range, so a preset clicked after some manual entry doesn't clobber it
  // with an unrelated default.
  presetSourceTimes() {
    for (const row of this.gridTarget.querySelectorAll("[data-day]")) {
      const [start, end] = this.rowTimes(row)
      if (start && end) return [start, end]
    }
    return [DEFAULT_START, DEFAULT_END]
  }

  rowTimes(row) {
    const [startInput, endInput] = row.querySelectorAll("input")
    return [startInput.value, endInput.value]
  }

  fillDay(day, start, end) {
    const row = this.gridTarget.querySelector(`[data-day="${day}"]`)
    if (!row) return

    const [startInput, endInput] = row.querySelectorAll("input")
    startInput.value = start
    endInput.value = end
  }
}
