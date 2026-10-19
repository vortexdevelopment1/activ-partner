import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';

// This config is used only by the isolated fixture server, never production.
// Opening otherwise internal dialog/wizard states lets the audit render the real
// components without submitting forms, uploading documents, or changing records.
export default defineConfig(({ mode }) => ({
  define: Object.fromEntries(Object.entries(loadEnv(mode, '.', 'VITE_')).map(([key,value]) => [`import.meta.env.${key}`, JSON.stringify(value)])),
  plugins: [{
    name: 'responsive-fixture-states', enforce: 'pre',
    transform(source, id) {
      const file = id.replace(/\\/g, '/').split('?')[0];
      let code = source;
      const select = (name: string) => `(new URLSearchParams(window.location.search).get('surface') === '${name}')`;
      if (file.endsWith('/CreateVenueModal.tsx')) {
        code = code.replace('const [step, setStep] = useState(0);', "const [step, setStep] = useState(Number(new URLSearchParams(window.location.search).get('surface')?.match(/^wizard-(\\d+)$/)?.[1] ?? 0));");
        code = code.replace('useState<FormState>(initialState())', 'useState<FormState>({ ...initialState(), ...(window as any).__fixtureVenueForm })');
        code = code.replace('const [showPartnerDropdown, setShowPartnerDropdown] = useState(false);', `const [showPartnerDropdown, setShowPartnerDropdown] = useState(${select('partner-search')});`);
        // The map itself is a third-party service; test its containing field layout.
        code = code.replace('if (open) loadGoogleMapsScript().catch(() => {});', '/* Maps disabled in isolated layout fixtures. */');
      }
      const detailCases = [
        ['/BankAccountDetail.tsx', 'bank'], ['/GstVerificationDetail.tsx', 'gst'],
        ['/VenueRequestDetail.tsx', 'request'], ['/VenueDetail.tsx', 'venue'],
      ];
      for (const [suffix, prefix] of detailCases) if (file.endsWith(suffix)) {
        for (const action of ['approve', 'reject', 'delete']) {
          const variable = `${action}Open`;
          const setter = `set${action[0].toUpperCase()}${action.slice(1)}Open`;
          code = code.replace(`const [${variable}, ${setter}] = useState(false);`, `const [${variable}, ${setter}] = useState(${select(`${prefix}-${action}`)});`);
        }
      }
      if (file.endsWith('/ActivityApprovalList.tsx')) code = code.replace('const [detailTarget, setDetailTarget] = useState<PendingActivity | null>(null);', `const [detailTarget, setDetailTarget] = useState<PendingActivity | null>(${select('activity-detail')} ? (window as any).__fixtureActivity : null);`);
      if (file.endsWith('/LogsList.tsx')) code = code.replace('useState<ActivityLog | null>(null)', `useState<ActivityLog | null>(${select('log-detail')} ? (window as any).__fixtureLog : null)`);
      if (file.endsWith('/NotificationsDropdown.tsx')) code = code.replace('useState(false)', `useState(${select('notifications')})`);
      if (file.endsWith('/GlobalSearch.tsx')) code = code.replaceAll('useState(false)', `useState(${select('search')})`);
      if (file.endsWith('/Layout.tsx')) code = code.replace('useState(false)', `useState(${select('sidebar')})`).replace('useEffect(() => { setMenuOpen(false); }, [location.pathname]);', '/* Keep fixture drawer open for measurement. */');
      if (file.endsWith('/SelectMenu.tsx')) code = code.replace('useState(false)', `useState(${select('select')})`);
      return code === source ? null : { code, map: null };
    },
  }, react()],
  server: { host: '127.0.0.1', port: 5174, strictPort: true },
}));
