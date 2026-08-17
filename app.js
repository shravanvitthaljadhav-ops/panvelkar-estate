const wingConfig = {
  R1A: {floors:13, flats:9, prefix:"R1A", fire:[6,9]},
  R1B: {floors:7, flats:2, prefix:"R1B", fire:[]},
  R2: {floors:12, flats:8, prefix:"R2", fire:[8]},
  R3: {floors:12, flats:8, prefix:"R3", fire:[8]},
  R4: {floors:12, flats:8, prefix:"R4", fire:[8]}
};

const wing = document.getElementById("wing");
const unit = document.getElementById("unit");
wing.addEventListener("change", ()=>{
  unit.innerHTML = '<option value="">Select flat</option>';
  const c=wingConfig[wing.value]; if(!c)return;
  for(let f=1;f<=c.floors;f++){
    for(let n=1;n<=c.flats;n++){
      const o=document.createElement("option");
      o.value=`${String(f).padStart(2,"0")}${String(n).padStart(2,"0")}`;
      o.textContent=`${wing.value} ${o.value}${c.fire.includes(f) ? " · fire flat(s) on floor" : ""}`;
      unit.appendChild(o);
    }
  }
});

document.getElementById("residentForm").addEventListener("submit",e=>{
  e.preventDefault();
  const data=Object.fromEntries(new FormData(e.target).entries());
  data.savedAt=new Date().toISOString();
  localStorage.setItem("pes_demo_last_record",JSON.stringify(data));
  document.getElementById("saved").textContent="Demo record saved in this browser.";
  e.target.reset(); unit.innerHTML='<option value="">Select wing first</option>';
});

const shops=document.getElementById("shopsGrid");
for(let i=1;i<=14;i++){
  const id=`ASH${String(i).padStart(2,"0")}`;
  shops.innerHTML += `<div class="shop">${id}<small>Shop details to be added</small></div>`;
}

const roles=["Chairman","Vice Chairman","Secretary","Joint Secretary","Treasurer","Joint Treasurer","Committee Member","Committee Member","Committee Member","Committee Member","Committee Member","Committee Member"];
const names=["Mr. Rajesh Patil","Mrs. Sneha Kulkarni","Mr. Amit Deshmukh","Mrs. Neha Joshi","Mr. Suresh More","Mrs. Pooja Shinde","Mr. Nitin Jadhav","Mrs. Kavita Pawar","Mr. Mahesh Sawant","Mrs. Rina Patil","Mr. Vijay Naik","Mrs. Anjali More"];
const committee=document.getElementById("committeeGrid");
roles.forEach((r,i)=>committee.innerHTML += `<article><strong>${r}</strong><span>${names[i]}</span><small>Demo name — replace before publishing</small></article>`);
