from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"Missing replacement target: {label}")
    return text.replace(old, new, 1)


eq_path = Path('src/pages/dashboard/Equipment.tsx')
text = eq_path.read_text()

text = replace_once(
    text,
    "  const [pendingSale, setPendingSale] = useState<InventoryItem | null>(null)\n",
    "  const [pendingSale, setPendingSale] = useState<InventoryItem | null>(null)\n  const [pendingDiscard, setPendingDiscard] = useState<InventoryItem | null>(null)\n",
    'pending discard state',
)
text = replace_once(
    text,
    "      if (event.key !== 'Escape' || pendingPurchase || pendingSale) return",
    "      if (event.key !== 'Escape' || pendingPurchase || pendingSale || pendingDiscard) return",
    'escape guard',
)
text = replace_once(
    text,
    "  }, [selectedMarketItem, selectedInventoryItem, pendingPurchase, pendingSale])",
    "  }, [selectedMarketItem, selectedInventoryItem, pendingPurchase, pendingSale, pendingDiscard])",
    'escape dependencies',
)

insert_discard = '''  async function discardItem() {\n    if (!pendingDiscard) return\n    const item = pendingDiscard\n    setBusy(`discard:${item.inventory_id}`)\n    setError(null)\n    setMessage(null)\n    const { error: discardError } = await supabase.rpc('discard_equipment_item_v1', { p_inventory_id: item.inventory_id })\n    if (discardError) setError(discardError.message)\n    else {\n      setMessage(`${item.item.brand} ${item.item.model} was discarded from Inventory.`)\n      setPendingDiscard(null)\n      setSelectedInventoryItem(null)\n      await loadEquipment()\n    }\n    setBusy(null)\n  }\n\n'''
text = replace_once(
    text,
    "  async function equipItem(item: InventoryItem) {",
    insert_discard + "  async function equipItem(item: InventoryItem) {",
    'discard action',
)

badge = "{discount > 0 && <div className=\"tlg-equipment-sponsor-price-badge\"><strong>SPONSOR DISCOUNT</strong><span>−{discount}%</span></div>}"
if badge not in text:
    raise SystemExit('Missing sponsor badge target')
text = text.replace(badge, '', 1)
quick = "<div className=\"tlg-equipment-card-quick\"><span>{item.surface ? surfaceLabel(item.surface) : item.weather_profile ? `${titleCase(item.weather_profile)} weather` : effectScopeLabel(item.effect_scope)}</span><span>Wear {item.wear_per_match ?? '—'}% / match</span></div><div className=\"bottom\">"
text = replace_once(
    text,
    quick,
    quick.replace('</div><div className=\"bottom\">', f'</div>{badge}<div className=\"bottom\">'),
    'move sponsor badge below weather row',
)
text = replace_once(
    text,
    "dashboard.balance < playerPrice(item) ? 'Insufficient funds' : `Buy ${money(playerPrice(item))}`",
    "dashboard.balance < playerPrice(item) ? 'Buy' : 'Buy'",
    'market buy button label',
)

text = replace_once(
    text,
    "{selectedInventoryItem && <InventoryDetailDialog entry={selectedInventoryItem} busy={busy} onClose={() => setSelectedInventoryItem(null)} onEquip={() => void equipItem(selectedInventoryItem)} onSell={() => setPendingSale(selectedInventoryItem)} />}",
    "{selectedInventoryItem && <InventoryDetailDialog entry={selectedInventoryItem} busy={busy} onClose={() => setSelectedInventoryItem(null)} onSell={() => setPendingSale(selectedInventoryItem)} onDiscard={() => setPendingDiscard(selectedInventoryItem)} />}",
    'inventory dialog props',
)

sale_dialog = "      {pendingSale && <GameConfirmDialog open eyebrow=\"Equipment resale\""
if sale_dialog not in text:
    raise SystemExit('Missing sale dialog insertion point')
discard_dialog = "      {pendingDiscard && <GameConfirmDialog open eyebrow=\"Discard equipment\" title={`Discard ${pendingDiscard.item.brand} ${pendingDiscard.item.model}?`} message={<>This permanently removes the item from Inventory. You will receive <strong>$0</strong>.</>} detail={pendingDiscard.is_equipped ? <>This item is currently equipped. Equip a replacement before discarding it.</> : <>Condition: <strong>{conditionText(pendingDiscard.condition)}</strong>. Purchased equipment can be discarded even when it has no resale value.</>} confirmLabel={pendingDiscard.is_equipped ? 'Replace before discarding' : 'Discard permanently'} tone=\"warning\" busy={busy === `discard:${pendingDiscard.inventory_id}`} onCancel={() => { if (!busy) setPendingDiscard(null) }} onConfirm={() => { if (!pendingDiscard.is_equipped) return discardItem() }} />}\n"
text = text.replace(sale_dialog, discard_dialog + sale_dialog, 1)

old_sig = "function InventoryDetailDialog({ entry, busy, onClose, onEquip, onSell }: { entry: InventoryItem; busy: string | null; onClose: () => void; onEquip: () => void; onSell: () => void }) {"
new_sig = "function InventoryDetailDialog({ entry, busy, onClose, onSell, onDiscard }: { entry: InventoryItem; busy: string | null; onClose: () => void; onSell: () => void; onDiscard: () => void }) {"
text = replace_once(text, old_sig, new_sig, 'inventory dialog signature')

old_actions = '''<div className="tlg-equipment-detail-actions tlg-equipment-inventory-detail-actions"><button type="button" className="secondary" onClick={onClose}>Close</button><button type="button" disabled={entry.is_equipped || busy === `equip:${entry.inventory_id}`} onClick={onEquip}>{entry.is_equipped ? 'Equipped' : busy === `equip:${entry.inventory_id}` ? 'Equipping…' : 'Equip'}</button><button type="button" className="danger" disabled={!entry.can_sell || busy === `sell:${entry.inventory_id}`} title={entry.sell_block_reason ?? `Sell for ${money(entry.resale_value_usd)}`} onClick={onSell}>{entry.can_sell ? `Sell ${money(entry.resale_value_usd)}` : entry.is_equipped && entry.resell_supported ? 'Replace before selling' : 'Not sellable'}</button></div>'''
new_actions = '''<div className="tlg-equipment-detail-actions tlg-equipment-inventory-detail-actions"><button type="button" className="secondary" onClick={onClose}>Close</button><button type="button" className="danger" disabled={!entry.can_sell || busy === `sell:${entry.inventory_id}`} title={entry.sell_block_reason ?? `Sell for ${money(entry.resale_value_usd)}`} onClick={onSell}>{entry.can_sell ? `Sell ${money(entry.resale_value_usd)}` : entry.is_equipped && entry.resell_supported ? 'Replace before selling' : 'Not sellable'}</button><button type="button" className="discard" disabled={entry.is_equipped || entry.acquired_source !== 'purchase' || busy === `discard:${entry.inventory_id}`} title={entry.is_equipped ? 'Equip a replacement before discarding this item.' : entry.acquired_source !== 'purchase' ? 'Only purchased equipment can be discarded.' : 'Discard this item for $0'} onClick={onDiscard}>{entry.is_equipped ? 'Replace before discarding' : entry.acquired_source !== 'purchase' ? 'Cannot discard' : 'Discard'}</button></div>'''
text = replace_once(text, old_actions, new_actions, 'inventory dialog actions')

eq_path.write_text(text)

refine_path = Path('src/styles/equipment-refinement-v2.css')
css = refine_path.read_text()
marker = '/* Equipment modal layout refinement v3 */'
if marker not in css:
    css += r'''

/* Equipment modal layout refinement v3 */
.tlg-equipment-detail .tlg-equipment-detail-media{position:relative!important;align-self:stretch!important;min-height:0!important;padding:0!important;overflow:hidden!important;background:#eef4f8!important}
.tlg-equipment-detail .tlg-equipment-detail-media .tlg-equipment-product-image.large{position:absolute!important;inset:0!important;width:100%!important;height:100%!important;min-height:0!important;max-height:none!important;border:0!important;border-radius:0!important;background:#eef4f8!important}
.tlg-equipment-detail .tlg-equipment-detail-media .tlg-equipment-product-image.large img{position:absolute!important;inset:0!important;display:block!important;width:100%!important;height:100%!important;max-width:none!important;max-height:none!important;object-fit:cover!important;object-position:center!important}
.tlg-equipment-inventory-detail .tlg-equipment-detail-media{background:#eef4f8!important}
.tlg-equipment-inventory-detail .tlg-equipment-detail-media .tlg-equipment-product-image.large img{object-fit:cover!important}

@media(min-width:901px){
  .tlg-equipment-detail-backdrop{overflow-y:auto!important;padding:16px!important}
  .tlg-equipment-detail{grid-template-columns:36% 64%!important;width:min(1040px,96vw)!important;height:min(860px,calc(100dvh - 32px))!important;max-height:calc(100dvh - 32px)!important;min-height:0!important}
  .tlg-equipment-detail-content{position:relative!important;min-height:0!important;overflow-y:auto!important;padding:27px 28px 24px!important}
  .tlg-equipment-detail-actions{position:sticky!important;right:auto!important;bottom:-24px!important;z-index:6!important;box-sizing:border-box!important;width:auto!important;margin:18px -28px -24px!important;padding:13px 28px 15px!important;border-top:1px solid #dfe8ee!important;background:rgba(255,255,255,.98)!important;box-shadow:0 -8px 22px rgba(16,47,70,.08)!important;backdrop-filter:blur(6px)}
}
@media(max-width:900px){
  .tlg-equipment-detail .tlg-equipment-detail-media{height:300px!important;min-height:300px!important}
  .tlg-equipment-detail-content{position:relative!important}
  .tlg-equipment-detail-actions{position:sticky!important;bottom:-24px!important;width:auto!important;margin:18px -28px -24px!important;padding:13px 28px 15px!important}
}

.tlg-equipment-inventory-detail-actions button.discard{border-color:#d6a663!important;color:#8c5a18!important;background:#fff8ed!important}
.tlg-equipment-inventory-detail-actions button.discard:not(:disabled):hover{background:#fff0d8!important}
'''
    refine_path.write_text(css)

sponsor_path = Path('src/styles/equipment-technical-sponsor.css')
css = sponsor_path.read_text()
marker = '/* Marketplace sponsor card placement refinement v3 */'
if marker not in css:
    css += r'''

/* Marketplace sponsor card placement refinement v3 */
.tlg-equipment-market-card-v2{display:flex!important;flex-direction:column!important}
.tlg-equipment-market-card-v2>.tlg-equipment-sponsor-price-badge{order:0;margin:10px 17px 0!important}
.tlg-equipment-market-card-v2>.bottom{width:auto;box-sizing:border-box;align-items:flex-end!important;margin-top:auto!important}
.tlg-equipment-market-card-buttons{margin-left:auto;align-self:flex-end;flex-wrap:nowrap!important}
.tlg-equipment-market-card-buttons button{min-width:76px!important;min-height:36px!important;padding:0 12px!important}
.tlg-equipment-market-card-buttons button.buy{min-width:72px!important}
.tlg-equipment-market-card-v2.sponsor-priced .tlg-equipment-card-quick{margin-bottom:0}
'''
    sponsor_path.write_text(css)
