// Panvelkar Estate Stanford
// Public-site JavaScript
//
// IMPORTANT:
// No administrator password, user list, or privileged credential is stored here.
// Admin/Super Admin authentication must be handled by Supabase Auth + RLS.

const committeeMembers = [
  { name: "श्री. विनय ठोबरे", role: "अध्यक्ष / Chairman" },
  { name: "श्री. श्रीकांत पाटील", role: "सचिव / Secretary" },
  { name: "श्री. कल्पेश घाग", role: "खजिनदार / Treasurer" },
  { name: "समिती सदस्य ०४", role: "समिती सदस्य / Committee Member" },
  { name: "समिती सदस्य ०५", role: "समिती सदस्य / Committee Member" },
  { name: "समिती सदस्य ०६", role: "समिती सदस्य / Committee Member" },
  { name: "समिती सदस्य ०७", role: "समिती सदस्य / Committee Member" },
  { name: "समिती सदस्य ०८", role: "समिती सदस्य / Committee Member" },
  { name: "समिती सदस्य ०९", role: "समिती सदस्य / Committee Member" },
  { name: "समिती सदस्य १०", role: "समिती सदस्य / Committee Member" },
  { name: "समिती सदस्य ११", role: "समिती सदस्य / Committee Member" },
  { name: "समिती सदस्य १२", role: "समिती सदस्य / Committee Member" }
];

const shops = Array.from({ length: 14 }, (_, i) => ({
  name: `दुकान क्र. ${String(i + 1).padStart(2, "0")}`,
  detail: "दुकानाची माहिती / Shop details"
}));

function openAdmin() {
  window.location.href = "portal.html";
}

function closeAdmin() {
  const modal = document.getElementById("adminModal");
  if (modal) modal.classList.remove("show");
}

function openModal(type) {
  const modal = document.getElementById("modal");
  const title = document.getElementById("modalTitle");
  const content = document.getElementById("modalContent");
  if (!modal || !title || !content) return;

  const isCommittee = type === "committee";
  const items = isCommittee ? committeeMembers : shops;
  title.textContent = isCommittee
    ? "व्यवस्थापन समिती / Management Committee"
    : "सोसायटीतील १४ दुकाने / 14 Shops";

  content.innerHTML = items.map((item, index) => {
    const initials = isCommittee ? "समिती" : String(index + 1).padStart(2, "0");
    return `<div class="modal-item">
      <div class="avatar" style="width:52px;height:52px;font-size:1rem;margin:0 0 9px">${initials}</div>
      <b>${item.name}</b>
      <span>${item.role || item.detail}</span>
    </div>`;
  }).join("");

  modal.classList.add("show");
  document.body.style.overflow = "hidden";
}

function closeModal() {
  const modal = document.getElementById("modal");
  if (modal) modal.classList.remove("show");
  document.body.style.overflow = "";
}

function contactAlert() {
  return "धन्यवाद! तुमचा संदेश नोंदवला आहे. / Thank you! Your message has been received.";
}

document.addEventListener("DOMContentLoaded", function () {
  const modal = document.getElementById("modal");
  if (modal) {
    modal.addEventListener("click", function (event) {
      if (event.target === modal) closeModal();
    });
  }

  document.addEventListener("keydown", function (event) {
    if (event.key === "Escape") closeModal();
  });
});