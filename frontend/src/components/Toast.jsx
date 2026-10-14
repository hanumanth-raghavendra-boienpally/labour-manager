import { createContext, useCallback, useContext, useState } from 'react';

const ToastContext = createContext(() => {});

/** toast(kind, title, body): kind is 'info' | 'ok' | 'bad'. */
export function ToastProvider({ children }) {
  const [items, setItems] = useState([]);
  const show = useCallback((kind, title, body) => {
    const id = Date.now() + Math.random();
    setItems(list => [...list, { id, kind, title, body }]);
    setTimeout(() => setItems(list => list.filter(t => t.id !== id)), kind === 'bad' ? 9000 : 5000);
  }, []);
  return (
    <ToastContext.Provider value={show}>
      {children}
      <div className="toasts" role="status" aria-live="polite">
        {items.map(t => (
          <div key={t.id} className={`tst ${t.kind === 'info' ? '' : t.kind}`}>
            <div><b>{t.title}</b>{t.body}</div>
            <button className="x" aria-label="Dismiss" onClick={() => setItems(list => list.filter(x => x.id !== t.id))}>×</button>
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}

export const useToast = () => useContext(ToastContext);
