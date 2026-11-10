// The Conjure Button demo: the same picking order as the addon's
// Modules/Conjure.lua. A mana gem if you have none, then water below your
// target, then food. Out of combat only; one cast per press.
(() => {
  const root = document.querySelector("#conjure-demo");
  if (!root) return;
  const ICON = (name) => `https://render.worldofwarcraft.com/us/icons/56/${name}.jpg`;

  // Targets are the addon's defaults (Settings > Conjure button). How much one
  // cast makes is a pretend amount for the demo, not a game number.
  const KINDS = [
    { kind: "gem", label: "Mana gem", spell: "Conjure Mana Gem", icon: ICON("inv_misc_gem_emerald_01"), want: 1, per: 1 },
    { kind: "water", label: "Water", spell: "Conjure Water", icon: ICON("inv_drink_06"), want: 20, per: 10 },
    { kind: "food", label: "Food", spell: "Conjure Food", icon: ICON("inv_misc_food_33"), want: 20, per: 10 },
  ];
  const START = { gem: 0, water: 4, food: 12 };

  let have = {};
  let combat = false;
  let flash = null;
  const list = root.querySelector(".party");
  const btn = root.querySelector(".conjure-btn");
  const status = root.querySelector(".demo-status");
  const combatRow = root.querySelector(".demo-combat");
  const combatBtn = root.querySelector(".combat-toggle");

  function next() {
    return KINDS.find((k) => have[k.kind] < k.want) || null;
  }

  function render() {
    const pick = combat ? null : next();
    list.innerHTML = "";
    for (const k of KINDS) {
      const n = have[k.kind];
      const low = n < k.want;
      const li = document.createElement("li");
      li.className = "member" + (low ? "" : " buffed") + (pick === k ? " next" : "") + (flash === k.kind ? " flash" : "");
      li.innerHTML = `<div class="who"><b></b><span></span></div><div class="state"><span class="tag"></span><img alt=""></div><div class="bar"><i></i></div>`;
      li.querySelector("b").textContent = k.label;
      li.querySelector(".who span").textContent = `${n} / ${k.want} in bags`;
      const tag = li.querySelector(".tag");
      tag.textContent = low ? (pick === k ? "next" : "low") : "stocked";
      tag.className = "tag " + (low ? (pick === k ? "" : "skip") : "ok");
      li.querySelector("img").src = k.icon;
      li.querySelector(".bar i").style.width = `${Math.min(100, (n / k.want) * 100)}%`;
      if (flash === k.kind) {
        const f = document.createElement("span");
        f.className = "cast-float";
        f.textContent = `+ ${k.per} ${k.label.toLowerCase()}`;
        li.append(f);
      }
      list.append(li);
    }
    flash = null;

    btn.disabled = !pick;
    btn.style.setProperty("--icon", `url("${(pick || KINDS[1]).icon}")`);
    btn.setAttribute("aria-label", pick ? `Cast ${pick.spell}` : "Nothing to conjure");
    combatRow.classList.toggle("on", combat);
    combatRow.querySelector("span").textContent = combat ? "In combat: the button is disarmed." : "Out of combat.";
    combatBtn.textContent = combat ? "Leave combat" : "Pull a mob";

    if (combat) {
      status.innerHTML = `<b>In combat</b><span>Conjuring is out of combat only. The button waits until the fight ends.</span>`;
    } else if (pick) {
      status.innerHTML = `<b></b><span>${have[pick.kind]} of ${pick.want} · press the button or <kbd>C</kbd></span>`;
      status.querySelector("b").textContent = `Next: ${pick.spell}`;
    } else {
      status.innerHTML = `<b>Stocked up</b><span>Gem, water and food are all at your targets.</span><br><button type="button" class="wow-btn small ghost reset">Reset the demo</button>`;
      status.querySelector(".reset").addEventListener("click", reset);
    }
  }

  function cast() {
    if (combat) return;
    const pick = next();
    if (!pick) return;
    have[pick.kind] += pick.per;
    flash = pick.kind;
    render();
    if (!next() && window.parzellesAchieve) {
      window.parzellesAchieve("conjure", "Well Stocked", "Conjured a full stock of gem, water and food.", pick.icon, 10);
    }
  }

  function reset() {
    have = { ...START };
    combat = false;
    render();
  }

  btn.addEventListener("click", cast);
  combatBtn.addEventListener("click", () => { combat = !combat; render(); });
  root.addEventListener("keydown", (e) => {
    if (e.key === "c" || e.key === "C") { e.preventDefault(); cast(); }
  });
  reset();
})();
