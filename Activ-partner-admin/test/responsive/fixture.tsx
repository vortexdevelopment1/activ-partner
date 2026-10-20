import React, { useEffect, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import axios from 'axios';
import api from '../../src/api/axios';
import App from '../../src/App';
import { useAuthStore } from '../../src/store/auth.store';
import { Modal } from '../../src/components/ui/Modal';
import { SelectMenu } from '../../src/components/ui/SelectMenu';
import { CategoryForm } from '../../src/pages/categories/CategoryForm';
import { QuestionForm } from '../../src/pages/questions/QuestionForm';
import { CommissionForm } from '../../src/pages/commissions/CommissionForm';
import { FAQForm } from '../../src/pages/faqs/FAQForm';
import { CreateVenueModal } from '../../src/pages/venues/CreateVenueModal';
import { ApproveModal } from '../../src/pages/venues/ApproveModal';
import { RejectModal } from '../../src/pages/venues/RejectModal';
import { RequestChangesModal } from '../../src/pages/venues/RequestChangesModal';
import { ApproveActivityModal } from '../../src/pages/activities/ApproveActivityModal';
import { RejectActivityModal } from '../../src/pages/activities/RejectActivityModal';
import { ConfirmDialog } from '../../src/components/common/ConfirmDialog';
import '../../src/index.css';

const surface = new URLSearchParams(location.search).get('surface') || '/dashboard';
const long = 'LongUnbrokenContent0123456789'.repeat(6);
const now = '2026-10-19T09:00:00.000Z';
const user = { id:'user', firstName:'Responsive', lastName:'AdministratorWithALongName', email:`${long}@example.test`, phone:'9000000000', role:'admin', isActive:true, createdAt:now };
const category = { id:'category', name:'Badminton', type:'court_booking', description:long, isActive:true, order:1, createdAt:now, updatedAt:now };
const partner = { ...user, id:'partner', businessName:'A partner with a longer business name', gstNumber:'TESTGST', panNumber:'TESTPAN', user };
const activity = { id:'activity', venueId:'venue', name:'Badminton with a longer activity name', categoryId:'category', category, description:long, pricePerHour:1250, minDuration:60, status:'pending', isActive:true, amenities:['Parking','Drinking water'], imageUrls:[], createdAt:now, updatedAt:now, submittedAt:now, venue:{ id:'venue', name:'Avenue one', city:'Ajmer', state:'Rajasthan' } };
const venue = { id:'venue', name:'Avenue one', partnerId:'partner', partner, description:long, address:'A longer building address in a city', flatBuilding:long, city:'Ajmer', state:'Rajasthan', country:'India', zipCode:'305001', phone:'9000000000', venuePhone:'9000000000', latitude:26.44, longitude:74.63, locationUrl:`https://maps.google.com/?q=place_id:${long}`, status:'rejected', isActive:false, bookingAccept:false, rejectionReason:`Does not meet quality standards: ${long}`, categories:[category], category, amenities:['Parking','Drinking water'], images:[], services:[activity], answers:[{id:'answer',questionId:'question',answer:long,question:{id:'question',questionText:'Describe your facilities',categoryId:'category',category}}], availability:{category:[{day:'Friday',slots:[{openTime:'09:00 AM',closeTime:'07:00 PM'}]}]}, commission:10, createdAt:now, updatedAt:now };
const request = { id:'request', venueId:'venue', venue, partnerId:'partner', partner, name:long, requestedChanges:{name:long}, status:'pending', createdAt:now, updatedAt:now };
const gst = { id:'gst', partnerId:'partner', partner, gstNumber:long, gstName:long, status:'pending', createdAt:now, updatedAt:now };
const bank = { id:'bank', partnerId:'partner', partner, accountHolderName:long, accountNumber:'12345678901234567890', bankName:long, branchName:long, ifscCode:'TEST0001234', accountType:'Current account', status:'under_review', createdAt:now, updatedAt:now };
const callback = { id:'callback', partnerId:'partner', partnerName:long, email:`${long}@example.test`, phone:'9000000000', venueName:'Avenue one', city:'Ajmer', callbackDate:'2026-10-20', callbackTime:'10:30 AM', query:long, status:'pending', adminNotes:long, createdAt:now, updatedAt:now };
const support = { id:'support', subject:'A longer support subject', message:long, status:'PENDING', attachments:[], created_at:now };
const notification = { id:'notification', type:'venue_updated', title:'A venue was updated', body:long, data:{venueId:'venue'}, isRead:false, createdAt:now };
(window as any).__fixtureActivity = activity;
(window as any).__fixtureLog = {id:'log',actor:long,action:'PATCH /venues/:id',resource:'venues',targetId:'venue',details:{outcome:'success'},createdAt:now};
(window as any).__fixtureVenueForm = { name:long, partnerLabel:long, description:long, address:long, flatBuilding:long,
  city:'Ajmer',state:'Rajasthan',zipCode:'305001',venuePhone:'9000000000',commission:'10',categoryIds:['category'],
  fullName:long,aadhaarNumber:'123456789012',panNumber:'ABCDE1234F',gstin:'TESTGST',amenities:['Parking'],answers:{question:long} };
const paginate = (items: any[]) => ({ items, total:55, page:1, limit:15, totalPages:4 });
const adapter = async (config: any) => {
  if (config.method && config.method !== 'get') throw new Error('Writes disabled in responsive fixtures');
  const path = new URL(config.url, 'http://fixture.test').pathname;
  let data: any = paginate([]);
  if (path.endsWith('/categories/active')) data = [category];
  else if (path === '/categories') data = paginate([category]);
  else if (path === '/questions') data = paginate([{ id:'question', categoryId:'category', questionText:long, questionType:'select', options:['A','B'], isActive:true, isRequired:true, createdAt:now }]);
  else if (path.startsWith('/questions/category/')) data = [{id:'question',categoryId:'category',questionText:long,questionType:'text',options:[],isRequired:true,isActive:true}];
  else if (path.endsWith('/admin/stats')) data = {total:100,pending:20,approved:70,rejected:10};
  else if (path.includes('/admin/activities/pending')) data = paginate([activity]);
  else if (path.includes('/update-requests')) data = path.endsWith('/request') ? request : paginate([request]);
  else if (path === '/venues/admin/all' || path === '/venues/admin/pending') data = paginate([venue]);
  else if (path.startsWith('/venues/admin/')) data = venue;
  else if (path === '/users') data = paginate([user]);
  else if (path === '/partners') data = paginate([partner]);
  else if (path.endsWith('/commissions/default')) data = {commissionPercentage:10};
  else if (path.endsWith('/commissions/cities')) data = paginate([{city:'Ajmer',state:'Rajasthan',commissionPercentage:10,source:'default'}]);
  else if (path.includes('/commissions')) data = paginate([]);
  else if (path === '/faqs') data = paginate([{id:'faq',question:long,answer:long,isActive:true,createdAt:now}]);
  else if (path.includes('/gst-verification')) data = path.endsWith('/gst') ? gst : paginate([gst]);
  else if (path.includes('/bank-accounts')) data = path.endsWith('/bank') ? bank : paginate([bank]);
  else if (path.includes('/support/callback')) data = path.endsWith('/callback/callback') ? callback : paginate([callback]);
  else if (path.includes('/support/email')) data = path.endsWith('/support') ? support : paginate([support]);
  else if (path.includes('/legal')) data = [{id:'legal',type:'terms_and_conditions',content:long,updatedAt:now}];
  else if (path.endsWith('/notifications/unread-count')) data = {count:17};
  else if (path.includes('/admin/notifications')) data = [notification];
  else if (path.endsWith('/logs/resources')) data = ['venues','partners'];
  else if (path.includes('/logs')) data = paginate([{id:'log',actor:long,action:'PATCH /venues/:id',resource:'venues',targetId:'venue',details:{outcome:'success'},createdAt:now}]);
  else if (path.includes('/admin/search')) data = [];
  return { data:{message:'Synthetic data',data},status:200,statusText:'OK',headers:{},config };
};
axios.defaults.adapter = adapter;
api.defaults.adapter = adapter;
useAuthStore.setState({user:user as any,token:'responsive-fixture',isAuthenticated:true});
const client = new QueryClient({defaultOptions:{queries:{retry:false,staleTime:Infinity}}});
const noop = () => {};
const props = {open:true,onClose:noop,onCancel:noop,onConfirm:noop,onSubmit:async()=>{},loading:false};
function Overlay() {
  if (surface === 'create-venue' || surface.startsWith('wizard-') || surface === 'partner-search') return <CreateVenueModal open onClose={noop}/>;
  if (surface === 'category') return <CategoryForm {...props} initial={{...category,name:long} as any}/>;
  if (surface === 'question') return <QuestionForm {...props} initial={{id:'question',questionText:long,questionType:'multiselect',options:[long,long],isActive:true} as any}/>;
  if (surface === 'commission') return <CommissionForm {...props} initial={{id:'commission',city:'Ajmer',state:'Rajasthan',commissionPercentage:10} as any}/>;
  if (surface === 'faq') return <FAQForm {...props} initial={{id:'faq',question:long,answer:long,isActive:true} as any}/>;
  if (surface === 'confirm') return <ConfirmDialog {...props} title="Permanently Delete Venue" message={long} confirmLabel="Permanently Delete"/>;
  if (surface === 'approve-venue') return <ApproveModal {...props} venueName={long}/>;
  if (surface === 'reject-venue') return <RejectModal {...props} venueName={long}/>;
  if (surface === 'request-changes') return <RequestChangesModal {...props} venueName={long}/>;
  if (surface === 'approve-activity') return <ApproveActivityModal {...props} activityName={long} venueName={long}/>;
  if (surface === 'reject-activity') return <RejectActivityModal {...props} activityName={long}/>;
  if (surface === 'select') return <Modal open onClose={noop} title="Dropdown at the end of a long form"><div style={{height:250}}>Scroll down to check dropdown placement.</div><SelectMenu value="" onChange={noop} ariaLabel="Responsive dropdown" placeholder="Select an option" options={Array.from({length:20},(_,index)=>({value:String(index),label:`Option ${index+1} ${long}`}))}/></Modal>;
  return null;
}
class Boundary extends React.Component<React.PropsWithChildren, {error:string}> {
  state = {error:''};
  static getDerivedStateFromError(error: Error) { return {error:error.message}; }
  render() { return this.state.error ? <p data-qa-error>{this.state.error}</p> : this.props.children; }
}
function Audit() {
  useEffect(() => {
    const timer = window.setTimeout(() => {
      const issues: string[] = [];
      const width = document.documentElement.clientWidth;
      const height = window.innerHeight;
      const scrollContainer = (node: Element) => {
        for (let parent = node.parentElement; parent; parent = parent.parentElement) {
          if (['auto','scroll'].includes(getComputedStyle(parent).overflowX) && parent.scrollWidth > parent.clientWidth + 2) return true;
        }
        return false;
      };
      for (const element of document.querySelectorAll<HTMLElement>('body *')) {
        if (element.closest('#admin-navigation') && width < 1024) continue;
        const rect = element.getBoundingClientRect();
        if (!rect.width || !rect.height || getComputedStyle(element).visibility === 'hidden') continue;
        if ((rect.right > width + 2 || rect.left < -2) && !scrollContainer(element)) {
          issues.push(`${element.tagName}.${element.className?.toString().slice(0,80)} extends ${Math.round(rect.left)}..${Math.round(rect.right)} outside 0..${width}`);
        }
      }
      const dialog = document.querySelector('[role="dialog"]')?.getBoundingClientRect();
      if (dialog && (dialog.top < -1 || dialog.bottom > height + 1)) issues.push('Dialog extends beyond viewport height');
      if (document.querySelector('[data-qa-error]')) issues.push(`Render failed: ${document.querySelector('[data-qa-error]')?.textContent}`);
      if (document.body.innerText.includes('Unable to load') || document.body.innerText.includes('Could not load')) issues.push('A fixture did not load successfully');
      parent.postMessage({kind:'responsive-audit',surface,width,height,issues:[...new Set(issues)]},location.origin);
    }, 650);
    return () => window.clearTimeout(timer);
  }, []);
  return null;
}
const surfacePath = surface.startsWith('bank-') ? '/bank-accounts/bank' : surface.startsWith('gst-') ? '/gst-verification/gst'
  : surface.startsWith('request-') && surface !== 'request-changes' ? '/venue-requests/request' : surface === 'venue-delete' ? '/venues/venue'
  : surface === 'activity-detail' ? '/activity-approvals' : surface === 'log-detail' ? '/logs' : '/dashboard';
createRoot(document.querySelector('#root')!).render(<QueryClientProvider client={client}><MemoryRouter initialEntries={[surface.startsWith('/') ? surface : surfacePath]}><Boundary><App/><Overlay/></Boundary><Audit/></MemoryRouter></QueryClientProvider>);
