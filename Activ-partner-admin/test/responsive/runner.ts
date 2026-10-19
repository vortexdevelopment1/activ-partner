const pages = ['/login', '/dashboard', '/categories', '/questions', '/venues', '/venues/venue', '/users', '/partners', '/commissions', '/faqs', '/gst-verification', '/gst-verification/gst', '/venue-requests', '/venue-requests/request', '/activity-approvals', '/legal', '/bank-accounts', '/bank-accounts/bank', '/support/callback', '/support/callback/callback', '/support/requests', '/support/requests/support', '/logs'];
const dialogs = ['create-venue', 'category', 'question', 'commission', 'faq', 'confirm', 'approve-venue', 'reject-venue', 'request-changes', 'approve-activity', 'reject-activity', 'select'];
const cases = [...pages, ...dialogs, 'wizard-1','wizard-2','wizard-3','wizard-4','wizard-5','wizard-6', 'bank-approve','bank-reject','gst-approve','gst-reject','request-approve','request-reject','venue-delete','activity-detail','log-detail','notifications','search','sidebar','partner-search'];
const sizes = [[320,640], [360,740], [390,844], [430,932], [640,360], [768,1024], [1024,768], [1280,800], [1440,900], [1920,1080]];
const surface = document.querySelector<HTMLSelectElement>('#surface')!;
const size = document.querySelector<HTMLSelectElement>('#size')!;
const summary = document.querySelector<HTMLElement>('#summary')!;
const results = document.querySelector<HTMLElement>('#results')!;
const preview = document.querySelector<HTMLElement>('#preview')!;
cases.forEach(value => surface.add(new Option(value, value)));
sizes.forEach(value => size.add(new Option(value.join(' × '), value.join(','))));
let frame: HTMLIFrameElement | null = null;
const active = new Map<Window, HTMLIFrameElement>();
let queue: Array<{ surface: string; width: number; height: number }> = [];
let count = 0, failures = 0, running = false;
const records: object[] = [];
const show = (name: string, width: number, height: number, audit = false) => {
  frame?.remove();
  frame = document.createElement('iframe');
  frame.width = String(width); frame.height = String(height);
  frame.title = `${name} at ${width} by ${height}`;
  frame.src = `./frame.html?surface=${encodeURIComponent(name)}&audit=${audit ? 1 : 0}&sample=${Date.now()}`;
  preview.append(frame);
};
const next = () => {
  if (!queue.length && !active.size) {
    running = false;
    summary.textContent = `COMPLETE: ${count} layouts checked; ${failures} layouts with issues. ${cases.length} screens/components × ${sizes.length} viewport sizes.`;
    return;
  }
  while (active.size < 3 && queue.length) {
    const job = queue.shift()!;
    summary.textContent = `Checking ${job.surface} at ${job.width} × ${job.height}. Completed ${count}; issues ${failures}.`;
    const item = document.createElement('iframe');
    item.width = String(job.width); item.height = String(job.height);
    item.title = `${job.surface} at ${job.width} by ${job.height}`;
    item.src = `./frame.html?surface=${encodeURIComponent(job.surface)}&audit=1&sample=${Date.now()}`;
    preview.append(item);
    active.set(item.contentWindow!, item);
  }
};
document.querySelector('#run')!.addEventListener('click', () => {
  count = 0; failures = 0; records.length = 0; results.textContent = ''; running = true;
  active.forEach(item => item.remove()); active.clear(); frame?.remove(); preview.replaceChildren();
  queue = cases.flatMap(name => sizes.map(([width, height]) => ({ surface: name, width, height })));
  next();
});
document.querySelector('#show')!.addEventListener('click', () => {
  running = false; queue = [];
  active.forEach(item => item.remove()); active.clear();
  const [width, height] = size.value.split(',').map(Number);
  show(surface.value, width, height);
  summary.textContent = `Preview: ${surface.value} at ${width} × ${height}. All mutations are disabled.`;
});
window.addEventListener('message', event => {
  if (event.origin !== location.origin || !active.has(event.source as Window) || event.data?.kind !== 'responsive-audit') return;
  const result = event.data;
  records.push(result);
  if (!running) return;
  active.get(event.source as Window)?.remove(); active.delete(event.source as Window);
  count++;
  if (result.issues.length) {
    failures++;
    const details = document.createElement('details'); details.className = 'fail';
    const title = document.createElement('summary'); title.textContent = `${result.surface} ${result.width} × ${result.height}: ${result.issues.length} issues`;
    const text = document.createElement('pre'); text.style.whiteSpace = 'pre-wrap'; text.textContent = JSON.stringify(result.issues, null, 2);
    details.append(title, text); results.append(details);
  }
  // The report remains readable in the browser and can be copied into a QA record.
  (window as any).responsiveAuditResults = records;
  next();
});
if (new URLSearchParams(location.search).get('run') === '1') document.querySelector<HTMLButtonElement>('#run')!.click();
else show('/venues/venue', 390, 844);
