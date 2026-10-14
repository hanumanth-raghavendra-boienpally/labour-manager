export function ConfirmModal({ title, children, confirmLabel, confirmClass = 'btn pri', busy, onConfirm, onCancel }) {
  return (
    <div className="modal-back" role="dialog" aria-modal="true" aria-labelledby="confirm-title"
         onKeyDown={e => { if (e.key === 'Escape') onCancel(); }}>
      <div className="modal">
        <div className="modal-h"><h3 id="confirm-title">{title}</h3></div>
        <div className="modal-b">{children}</div>
        <div className="modal-a">
          <button className="btn" onClick={onCancel} disabled={busy}>Cancel</button>
          <button className={confirmClass} onClick={onConfirm} disabled={busy} autoFocus>
            {busy ? <span className="spin" /> : null} {confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}
