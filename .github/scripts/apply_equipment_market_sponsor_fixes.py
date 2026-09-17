from pathlib import Path
import re


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"Missing replacement target: {label}")
    return text.replace(old, new, 1)


eq_path = Path('src/pages/dashboard/Equipment.tsx')
text = eq_path.read_text()

text = replace_once(
    text,
    'Inspect condition-adjusted bonuses, brand identity, durability, sponsor replacement eligibility and resale value.',
    'Inspect condition-adjusted bonuses, brand identity, durability and resale value.',
    'inventory header copy',
)

# Technical sponsorship is discount-only: remove free-claim/replacement client state and actions.
text = text.replace("  const [pendingFreeClaim, setPendingFreeClaim] = useState<CatalogItem | null>(null)\n", "")
text = text.replace("  const [pendingReplacement, setPendingReplacement] = useState<InventoryItem | null>(null)\n", "")
text = text.replace(
    "      if (event.key !== 'Escape' || pendingPurchase || pendingSale || pendingFreeClaim || pendingReplacement) return",
    "      if (event.key !== 'Escape' || pendingPurchase || pendingSale) return",
)
text = text.replace(
    "  }, [selectedMarketItem, selectedInventoryItem, pendingPurchase, pendingSale, pendingFreeClaim, pendingReplacement])",
    "  }, [selectedMarketItem, selectedInventoryItem, pendingPurchase, pendingSale])",
)

text, n = re.subn(
    r"\n  async function claimFreeItem\(\) \{.*?\n  async function sellItem\(\) \{",
    "\n  async function sellItem() {",
    text,
    count=1,
    flags=re.S,
)
if n != 1:
    raise SystemExit('Could not remove retired sponsor claim/replacement actions')

text = replace_once(
    text,
    "<div className=\"tlg-equipment-owned-facts\"><span>Wear / match <b>{entry.item.wear_per_match ?? '—'}%</b></span><span>{entry.sponsor_replacement_available ? 'Sponsor replacement' : 'Resale'} <b>{entry.sponsor_replacement_available ? `${entry.sponsor_replacements_remaining ?? 0} available` : entry.resell_supported ? money(entry.resale_value_usd) : 'Not supported'}</b></span></div>",
    "<div className=\"tlg-equipment-owned-facts\"><span>Wear / match <b>{entry.item.wear_per_match ?? '—'}%</b></span><span>Resale <b>{entry.resell_supported ? money(entry.resale_value_usd) : 'Not supported'}</b></span></div>",
    'inventory sponsor replacement fact',
)

text = replace_once(
    text,
    '<div className="tlg-equipment-sponsor-price-badge">Technical sponsor · −{discount}%</div>',
    '<div className="tlg-equipment-sponsor-price-badge"><strong>SPONSOR DISCOUNT</strong><span>−{discount}%</span></div>',
    'sponsor badge',
)

old_market_bottom = "<div className=\"bottom\"><div>{discount > 0 && <span className=\"tlg-equipment-list-price\">Normal {money(item.price_usd)}</span>}<strong>{money(playerPrice(item))}</strong><span>{item.sponsor_free_claim_available ? `${item.sponsor_free_equipment_remaining} free sponsor claim${item.sponsor_free_equipment_remaining === 1 ? '' : 's'}` : owned > 0 ? `${owned} owned` : `${item.estimated_uses ?? '—'} est. uses`}</span></div><button type=\"button\" onClick={() => setSelectedMarketItem(item)}>View details</button></div>"
new_market_bottom = "<div className=\"bottom\"><div className=\"tlg-equipment-market-price-stack\">{discount > 0 && <span className=\"tlg-equipment-list-price\">Normal {money(item.price_usd)}</span>}<strong className={discount > 0 ? 'tlg-equipment-sponsor-final-price' : ''}>{money(playerPrice(item))}</strong>{discount > 0 && <span className=\"tlg-equipment-sponsor-saving\">You save {money(Math.max(0, item.price_usd - playerPrice(item)))}</span>}<span>{owned > 0 ? `${owned} owned` : `${item.estimated_uses ?? '—'} est. uses`}</span></div><div className=\"tlg-equipment-market-card-buttons\"><button type=\"button\" className=\"secondary\" onClick={() => setSelectedMarketItem(item)}>View details</button><button type=\"button\" className=\"buy\" disabled={item.availability_status !== 'available' || dashboard.balance < playerPrice(item)} onClick={() => requestPurchase(item)}>{item.availability_status !== 'available' ? availabilityLabel(item.availability_status) : dashboard.balance < playerPrice(item) ? 'Insufficient funds' : `Buy ${money(playerPrice(item))}`}</button></div></div>"
text = replace_once(text, old_market_bottom, new_market_bottom, 'market bottom purchase controls')

text = replace_once(
    text,
    ' onBuy={() => requestPurchase(selectedMarketItem)} onClaim={() => setPendingFreeClaim(selectedMarketItem)} />',
    ' onBuy={() => requestPurchase(selectedMarketItem)} />',
    'market detail props',
)
text = replace_once(
    text,
    ' onSell={() => setPendingSale(selectedInventoryItem)} onReplace={() => setPendingReplacement(selectedInventoryItem)} />',
    ' onSell={() => setPendingSale(selectedInventoryItem)} />',
    'inventory detail props',
)

text, n = re.subn(
    r"\n      \{pendingFreeClaim && <GameConfirmDialog .*? />\}\n      \{pendingReplacement && <GameConfirmDialog .*? />\}",
    "",
    text,
    count=1,
    flags=re.S,
)
if n != 1:
    raise SystemExit('Could not remove retired free sponsor confirmation dialogs')

text = replace_once(
    text,
    "function ItemDetailDialog({ item, balance, equipped, onClose, onBuy, onClaim }: { item: CatalogItem; balance: number; equipped?: EquippedSlot | null; onClose: () => void; onBuy: () => void; onClaim: () => void }) {",
    "function ItemDetailDialog({ item, balance, equipped, onClose, onBuy }: { item: CatalogItem; balance: number; equipped?: EquippedSlot | null; onClose: () => void; onBuy: () => void }) {",
    'ItemDetailDialog signature',
)
text = re.sub(
    r"\{item\.sponsor_free_claim_available && <div className=\"tlg-equipment-current-compare\">.*?</div>\}",
    "",
    text,
    count=1,
    flags=re.S,
)
text = text.replace("{item.sponsor_free_claim_available && <button type=\"button\" className=\"sponsor\" onClick={onClaim}>Claim free</button>}", "")

text = replace_once(
    text,
    "function InventoryDetailDialog({ entry, busy, onClose, onEquip, onSell, onReplace }: { entry: InventoryItem; busy: string | null; onClose: () => void; onEquip: () => void; onSell: () => void; onReplace: () => void }) {",
    "function InventoryDetailDialog({ entry, busy, onClose, onEquip, onSell }: { entry: InventoryItem; busy: string | null; onClose: () => void; onEquip: () => void; onSell: () => void }) {",
    'InventoryDetailDialog signature',
)
text = re.sub(
    r"\{entry\.sponsor_replacement_available && <div className=\"tlg-equipment-current-compare\">.*?</div>\}",
    "",
    text,
    count=1,
    flags=re.S,
)
text = text.replace("{entry.sponsor_replacement_available && <button type=\"button\" className=\"sponsor\" onClick={onReplace}>Free replacement</button>}", "")

eq_path.write_text(text)

panel_path = Path('src/components/equipment/TechnicalSponsorsPanel.tsx')
text = panel_path.read_text()
text = replace_once(
    text,
    'One exclusive equipment sponsor per category. Offers are based only on your current world ranking and every signed agreement runs until the end of its season.',
    'One exclusive equipment sponsor per category. Contracts provide marketplace discounts only, are based on your current world ranking and run until the end of the season.',
    'technical sponsor header copy',
)
text = replace_once(
    text,
    '<dl className="tlg-technical-contract-facts"><div><dt>Contract</dt><dd>Until season end</dd></div><div><dt>Free equipment</dt><dd>{active.free_equipment_remaining}/{active.free_equipment_allowance_total}</dd></div><div><dt>Replacements</dt><dd>{active.free_replacements_remaining}/{active.free_replacements_total}</dd></div><div><dt>Signed at</dt><dd>World #{active.player_rank_at_sign}</dd></div></dl>',
    '<dl className="tlg-technical-contract-facts"><div><dt>Contract</dt><dd>Until season end</dd></div><div><dt>Marketplace</dt><dd>{pct(active.discount_pct)} off</dd></div><div><dt>Premium Tier 4–5</dt><dd>{Number(active.premium_discount_bonus_pct) > 0 ? `+${pct(active.premium_discount_bonus_pct)}` : \'Same discount\'}</dd></div><div><dt>Signed at</dt><dd>World #{active.player_rank_at_sign}</dd></div></dl>',
    'active sponsor facts',
)
text = replace_once(
    text,
    '<div className="tlg-technical-offer-benefits"><span>Until season end</span><span>{offer.free_equipment_allowance} free items</span><span>{offer.free_replacement_allowance} replacements</span>{Number(offer.signing_bonus_usd) > 0 && <span>{money(offer.signing_bonus_usd)} signing bonus</span>}{offer.premium_discount_bonus_pct > 0 && <span>+{pct(offer.premium_discount_bonus_pct)} premium</span>}</div>',
    '<div className="tlg-technical-offer-benefits"><span>Until season end</span><span>Discount-only equipment deal</span>{Number(offer.signing_bonus_usd) > 0 && <span>{money(offer.signing_bonus_usd)} signing bonus</span>}{offer.premium_discount_bonus_pct > 0 && <span>+{pct(offer.premium_discount_bonus_pct)} premium-item discount</span>}</div>',
    'technical sponsor benefit chips',
)
text = replace_once(
    text,
    '<details><summary>Review full offer</summary><dl className="tlg-technical-offer-review"><div><dt>Marketplace discount</dt><dd>{pct(offer.discount_pct)}</dd></div><div><dt>Signing payment</dt><dd>{Number(offer.signing_bonus_usd) > 0 ? money(offer.signing_bonus_usd) : \'No signing payment\'}</dd></div><div><dt>Free equipment allowance</dt><dd>{offer.free_equipment_allowance}</dd></div><div><dt>Free worn-item replacements</dt><dd>{offer.free_replacement_allowance}</dd></div><div><dt>Premium Tier 4–5 bonus</dt><dd>{offer.premium_discount_bonus_pct ? `+${pct(offer.premium_discount_bonus_pct)}` : \'None\'}</dd></div><div><dt>Eligibility</dt><dd>Current ranking only · {offer.requirements.rank_group_label} (#{offer.requirements.rank_best}–#{offer.requirements.rank_worst})</dd></div><div><dt>Your ranking at offer</dt><dd>World #{offer.player_rank}</dd></div><div><dt>Contract term</dt><dd>Signing/start date through season end</dd></div><div><dt>Offer expiry</dt><dd>In {offer.days_until_expiry} days</dd></div></dl></details>',
    '<details><summary>Review full offer</summary><dl className="tlg-technical-offer-review"><div><dt>Marketplace discount</dt><dd>{pct(offer.discount_pct)}</dd></div><div><dt>Signing payment</dt><dd>{Number(offer.signing_bonus_usd) > 0 ? money(offer.signing_bonus_usd) : \'No signing payment\'}</dd></div><div><dt>Equipment benefit</dt><dd>Discounted purchases only</dd></div><div><dt>Premium Tier 4–5 bonus</dt><dd>{offer.premium_discount_bonus_pct ? `+${pct(offer.premium_discount_bonus_pct)}` : \'Same base discount\'}</dd></div><div><dt>Eligibility</dt><dd>Current ranking only · {offer.requirements.rank_group_label} (#{offer.requirements.rank_best}–#{offer.requirements.rank_worst})</dd></div><div><dt>Your ranking at offer</dt><dd>World #{offer.player_rank}</dd></div><div><dt>Contract term</dt><dd>Signing/start date through season end</dd></div><div><dt>Offer expiry</dt><dd>In {offer.days_until_expiry} days</dd></div></dl></details>',
    'technical sponsor offer review',
)
text = replace_once(
    text,
    'detail={<>{Number(pendingSign.signing_bonus_usd) > 0 ? <>Signing payment: <strong>{money(pendingSign.signing_bonus_usd)}</strong>. </> : null}Free equipment: <strong>{pendingSign.free_equipment_allowance}</strong>. The agreement is based on your current world ranking of <strong>#{pendingSign.player_rank}</strong>.</>}',
    'detail={<>{Number(pendingSign.signing_bonus_usd) > 0 ? <>Signing payment: <strong>{money(pendingSign.signing_bonus_usd)}</strong>. </> : null}Sponsored equipment remains a normal Marketplace purchase at the contract discount. The agreement is based on your current world ranking of <strong>#{pendingSign.player_rank}</strong>.</>}',
    'technical sponsor sign confirmation',
)
panel_path.write_text(text)

sponsor_css_path = Path('src/styles/equipment-technical-sponsor.css')
css = sponsor_css_path.read_text()
marker = '/* Discount-only technical sponsor marketplace presentation */'
if marker not in css:
    css += r'''

/* Discount-only technical sponsor marketplace presentation */
.tlg-equipment-market-card-v2.sponsor-priced{border-color:#a9d8bd;box-shadow:inset 0 3px 0 #2f9a68,0 7px 20px rgba(32,118,77,.09)}
.tlg-equipment-sponsor-price-badge{display:flex;align-items:center;justify-content:space-between;gap:10px;margin:10px 17px 0;padding:8px 10px;border:1px solid #efbbbb;border-radius:8px;color:#9d3434;background:#fff2f2;font-size:.56rem;font-weight:850;letter-spacing:.02em}
.tlg-equipment-sponsor-price-badge strong{font-size:.55rem;letter-spacing:.07em}
.tlg-equipment-sponsor-price-badge span{font-size:.68rem;font-weight:900;white-space:nowrap}
.tlg-equipment-market-price-stack{display:grid;align-content:end;justify-items:start;gap:2px;min-width:0}
.tlg-equipment-market-card-v2.sponsor-priced .tlg-equipment-list-price{color:#9c7777!important;font-size:.56rem!important}
.tlg-equipment-sponsor-final-price{color:#16834f!important;font-size:1.08rem!important;line-height:1.05}
.tlg-equipment-sponsor-saving{color:#23845a!important;font-size:.55rem!important;font-weight:850!important}
.tlg-equipment-market-card-buttons{display:flex;align-items:center;justify-content:flex-end;gap:7px;flex-wrap:wrap}
.tlg-equipment-market-card-buttons button{min-width:0!important;min-height:36px;padding:0 12px;border:1px solid #177db8;border-radius:8px;color:#fff;background:#177db8;font-size:.61rem;font-weight:850;cursor:pointer}
.tlg-equipment-market-card-buttons button.secondary{border-color:#cbd9e2;color:#4d687b;background:#fff}
.tlg-equipment-market-card-buttons button.buy{border-color:#247b52;background:#27875a}
.tlg-equipment-market-card-buttons button:disabled{opacity:.48;cursor:not-allowed}
'''
sponsor_css_path.write_text(css)

refine_path = Path('src/styles/equipment-refinement-v2.css')
css = refine_path.read_text()
marker = '/* Equipment detail modal: keep purchasing controls reachable at every desktop viewport height. */'
if marker not in css:
    css += r'''

/* Equipment detail modal: keep purchasing controls reachable at every desktop viewport height. */
@media(min-width:901px){
  .tlg-equipment-detail-backdrop{overflow-y:auto!important;padding:16px!important}
  .tlg-equipment-detail{grid-template-columns:36% 64%!important;width:min(1040px,96vw)!important;height:min(860px,calc(100dvh - 32px))!important;max-height:calc(100dvh - 32px)!important;min-height:0!important}
  .tlg-equipment-detail-content{min-height:0!important;overflow-y:auto!important;padding-bottom:86px!important}
  .tlg-equipment-detail-actions{position:absolute!important;right:0!important;bottom:0!important;z-index:6!important;box-sizing:border-box!important;width:64%!important;margin:0!important;padding:13px 28px 15px!important;border-top:1px solid #dfe8ee!important;background:rgba(255,255,255,.97)!important;box-shadow:0 -8px 22px rgba(16,47,70,.08)!important;backdrop-filter:blur(6px)}
  .tlg-equipment-detail:not(.tlg-equipment-inventory-detail) .tlg-equipment-detail-media{height:100%!important;min-height:0!important}
  .tlg-equipment-detail:not(.tlg-equipment-inventory-detail) .tlg-equipment-detail-media .tlg-equipment-product-image.large{height:100%!important;min-height:0!important}
}
@media(max-width:900px){
  .tlg-equipment-detail-backdrop{overflow-y:auto!important}
  .tlg-equipment-detail{height:auto!important;max-height:96dvh!important}
  .tlg-equipment-detail-content{min-height:0!important;overflow-y:auto!important}
  .tlg-equipment-detail-actions{position:sticky!important;bottom:-1px!important;z-index:6!important;border-top:1px solid #dfe8ee!important;background:#fff!important;box-shadow:0 -6px 18px rgba(16,47,70,.07)!important}
}
'''
refine_path.write_text(css)
