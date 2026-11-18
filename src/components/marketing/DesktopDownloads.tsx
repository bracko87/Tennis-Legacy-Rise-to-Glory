/**
 * Public desktop download actions, shared by homepage and public footer.
 * Binary files are hosted as versioned GitHub release assets rather than
 * bundled into the Netlify website.
 */
import { ArrowDownToLine, Monitor, Terminal, Gamepad2 } from 'lucide-react'
import { useLocalization } from '../../i18n/LocalizationProvider'
import type { AppLocale } from '../../i18n'
import '../../styles/desktop-downloads.css'

export const WINDOWS_DESKTOP_DOWNLOAD = 'https://github.com/bracko87/Tennis-Legacy-Rise-to-Glory/releases/download/desktop-v0.1.1/TennisLegacy-Setup-0.1.1-x64.exe'
export const LINUX_DESKTOP_DOWNLOAD = 'https://github.com/bracko87/Tennis-Legacy-Rise-to-Glory/releases/download/desktop-v0.1.1/TennisLegacy-0.1.1-x86_64.AppImage'

const desktopCopy: Record<AppLocale, {
  eyebrow: string; title: string; description: string; windows: string; linux: string; steam: string; coming: string; small: string; note: string
}> = {
  en: { eyebrow: 'PLAY ON YOUR COMPUTER', title: 'Tennis Legacy on Desktop', description: 'Play in your browser or download the same online multiplayer game for your computer. Your account, tournaments and rankings stay connected.', windows: 'Download for Windows', linux: 'Download for Linux', steam: 'Steam', coming: 'Coming soon', small: 'PC downloads', note: 'Free online multiplayer · Internet connection required' },
  sr: { eyebrow: 'IGRAJTE NA RAČUNARU', title: 'Tennis Legacy za računar', description: 'Igrajte u pregledaču ili preuzmite istu onlajn igru za računar. Nalog, turniri i rangiranje ostaju povezani.', windows: 'Preuzmi za Windows', linux: 'Preuzmi za Linux', steam: 'Steam', coming: 'Uskoro', small: 'Preuzimanja za PC', note: 'Besplatan onlajn multiplayer · Potreban je internet' },
  de: { eyebrow: 'AUF DEM COMPUTER SPIELEN', title: 'Tennis Legacy für Desktop', description: 'Spiele im Browser oder lade dasselbe Online-Multiplayer-Spiel auf deinen Computer. Konto, Turniere und Ranglisten bleiben verbunden.', windows: 'Für Windows herunterladen', linux: 'Für Linux herunterladen', steam: 'Steam', coming: 'Bald verfügbar', small: 'PC-Downloads', note: 'Kostenloser Online-Mehrspielermodus · Internet erforderlich' },
  es: { eyebrow: 'JUEGA EN TU ORDENADOR', title: 'Tennis Legacy para escritorio', description: 'Juega en el navegador o descarga el mismo juego multijugador en línea. Tu cuenta, torneos y clasificaciones siguen conectados.', windows: 'Descargar para Windows', linux: 'Descargar para Linux', steam: 'Steam', coming: 'Próximamente', small: 'Descargas para PC', note: 'Multijugador en línea gratuito · Requiere internet' },
  it: { eyebrow: 'GIOCA SUL COMPUTER', title: 'Tennis Legacy per desktop', description: 'Gioca nel browser o scarica lo stesso gioco multiplayer online. Account, tornei e classifiche restano collegati.', windows: 'Scarica per Windows', linux: 'Scarica per Linux', steam: 'Steam', coming: 'Prossimamente', small: 'Download per PC', note: 'Multiplayer online gratuito · Connessione Internet richiesta' },
  fr: { eyebrow: 'JOUEZ SUR ORDINATEUR', title: 'Tennis Legacy sur ordinateur', description: 'Jouez dans votre navigateur ou téléchargez le même jeu multijoueur en ligne. Votre compte, vos tournois et classements restent liés.', windows: 'Télécharger pour Windows', linux: 'Télécharger pour Linux', steam: 'Steam', coming: 'Bientôt', small: 'Téléchargements PC', note: 'Multijoueur en ligne gratuit · Connexion Internet requise' },
  ru: { eyebrow: 'ИГРАЙТЕ НА КОМПЬЮТЕРЕ', title: 'Tennis Legacy для ПК', description: 'Играйте в браузере или скачайте ту же многопользовательскую онлайн-игру. Аккаунт, турниры и рейтинги будут общими.', windows: 'Скачать для Windows', linux: 'Скачать для Linux', steam: 'Steam', coming: 'Скоро', small: 'Скачать для ПК', note: 'Бесплатная онлайн-игра · Требуется интернет' },
  pt: { eyebrow: 'JOGUE NO COMPUTADOR', title: 'Tennis Legacy para desktop', description: 'Jogue no navegador ou baixe o mesmo jogo multijogador online. Sua conta, torneios e rankings continuam conectados.', windows: 'Baixar para Windows', linux: 'Baixar para Linux', steam: 'Steam', coming: 'Em breve', small: 'Downloads para PC', note: 'Multijogador online gratuito · Requer internet' },
}

export default function DesktopDownloads({ compact = false }: { readonly compact?: boolean }) {
  const { locale } = useLocalization()
  const text = desktopCopy[locale] ?? desktopCopy.en

  if (compact) {
    return (
      <nav className="tlg-footer-downloads" aria-label={text.small}>
        <span className="tlg-footer-download-title">{text.small}</span>
        <div className="tlg-footer-download-links">
          <a href={WINDOWS_DESKTOP_DOWNLOAD} title={text.windows}>
            <Monitor size={16} aria-hidden="true" /> Windows <ArrowDownToLine size={13} aria-hidden="true" />
          </a>
          <a href={LINUX_DESKTOP_DOWNLOAD} title={text.linux}>
            <Terminal size={16} aria-hidden="true" /> Linux <ArrowDownToLine size={13} aria-hidden="true" />
          </a>
          <span className="tlg-footer-steam-disabled" aria-disabled="true" title={text.coming}>
            <Gamepad2 size={16} aria-hidden="true" /> Steam · {text.coming}
          </span>
        </div>
      </nav>
    )
  }

  return (
    <section id="desktop-downloads" className="tlg-content-section tlg-desktop-download-section" aria-labelledby="desktop-download-title">
      <div className="tlg-section">
        <div className="tlg-desktop-download-panel">
          <div className="tlg-desktop-download-copy">
            <span className="tlg-desktop-download-eyebrow">{text.eyebrow}</span>
            <h2 id="desktop-download-title">{text.title}</h2>
            <p>{text.description}</p>
            <small>{text.note}</small>
          </div>
          <div className="tlg-desktop-download-actions" aria-label={text.small}>
            <a className="tlg-desktop-download-button" href={WINDOWS_DESKTOP_DOWNLOAD} aria-label={text.windows}>
              <Monitor size={20} aria-hidden="true" /> <span>{text.windows}</span> <ArrowDownToLine size={17} aria-hidden="true" />
            </a>
            <a className="tlg-desktop-download-button" href={LINUX_DESKTOP_DOWNLOAD} aria-label={text.linux}>
              <Terminal size={20} aria-hidden="true" /> <span>{text.linux}</span> <ArrowDownToLine size={17} aria-hidden="true" />
            </a>
            <span className="tlg-desktop-download-button tlg-desktop-download-button-disabled" aria-disabled="true" title={text.coming}>
              <Gamepad2 size={20} aria-hidden="true" /><span>{text.steam} · {text.coming}</span>
            </span>
          </div>
        </div>
      </div>
    </section>
  )
}
