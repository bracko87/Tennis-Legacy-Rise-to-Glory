export const premiumToggleLabels: Record<string, {show:string;hide:string}> = {
  en: {show:'Show report',hide:'Hide report'},
  sr: {show:'Prikaži izveštaj',hide:'Sakrij izveštaj'},
  de: {show:'Bericht anzeigen',hide:'Bericht ausblenden'},
  es: {show:'Mostrar informe',hide:'Ocultar informe'},
  it: {show:'Mostra rapporto',hide:'Nascondi rapporto'},
  fr: {show:'Afficher le rapport',hide:'Masquer le rapport'},
  ru: {show:'Показать отчёт',hide:'Скрыть отчёт'},
  pt: {show:'Mostrar relatório',hide:'Ocultar relatório'},
}
export function premiumToggleText(language: string|undefined): {show:string;hide:string} {
  return premiumToggleLabels[(language??'en').toLowerCase().split('-')[0]] ?? premiumToggleLabels.en
}
