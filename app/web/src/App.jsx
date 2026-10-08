import { createElement, useEffect, useMemo, useState } from 'react'
import { request } from './api'
import {
  authConfigured,
  existingAdminSession,
  signInAdmin,
  signOutAdmin,
} from './auth'
import './styles.css'

function shuffled(items) {
  const copy = [...items]
  for (let i = copy.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[copy[i], copy[j]] = [copy[j], copy[i]]
  }
  return copy
}

function Quiz() {
  const [questions, setQuestions] = useState([])
  const [answers, setAnswers] = useState({})
  const [result, setResult] = useState(null)
  const [seconds, setSeconds] = useState(600)
  const [error, setError] = useState('')

  useEffect(() => {
    request('/api/questions').then(rows => setQuestions(shuffled(rows).map(q => ({
      ...q,
      displayOptions: shuffled(q.options.map((text, originalIndex) => ({ text, originalIndex }))),
    })))).catch(e => setError(e.message))
  }, [])
  useEffect(() => {
    if (result || seconds <= 0) return
    const id = setInterval(() => setSeconds(s => s - 1), 1000)
    return () => clearInterval(id)
  }, [result, seconds])

  const time = useMemo(() => `${String(Math.floor(seconds / 60)).padStart(2,'0')}:${String(seconds % 60).padStart(2,'0')}`, [seconds])

  async function submit() {
    const payload = { answers: questions.map(q => ({ question_id: q.id, selected_index: answers[q.id] ?? -1 })).filter(a => a.selected_index >= 0) }
    if (payload.answers.length !== questions.length) { setError('Answer every question before submitting.'); return }
    try { setResult(await request('/api/quiz/submit', { method: 'POST', body: JSON.stringify(payload) })); setError('') }
    catch (e) { setError(e.message) }
  }

  function retry() { setAnswers({}); setResult(null); setSeconds(600); setError(''); window.scrollTo(0,0) }

  if (!questions.length && !error) return <p>Loading quiz…</p>
  return <>
    <div className="toolbar"><strong>Science Quiz</strong><span>Time {time}</span></div>
    {error && <p className="error">{error}</p>}
    {questions.map((q, index) => <section className="card" key={q.id}>
      <h3>{index + 1}. {q.prompt}</h3>
      {q.displayOptions.map((option) => <label className="option" key={option.originalIndex}>
        <input type="radio" name={`q-${q.id}`} checked={answers[q.id] === option.originalIndex} onChange={() => setAnswers(a => ({...a, [q.id]: option.originalIndex}))}/>{option.text}
      </label>)}
      {result && (() => { const r = result.results.find(x => x.question_id === q.id); return r ? <p className={r.correct ? 'good' : 'bad'}>{r.correct ? 'Correct' : `Correct answer: ${q.options[r.correct_index]}`}. {r.explanation}</p> : null })()}
    </section>)}
    {!result ? <button onClick={submit}>Submit quiz</button> : <div className="result"><h2>{result.score}/{result.total} — {result.percentage}%</h2><button onClick={retry}>Retry quiz</button></div>}
  </>
}

function Admin() {
  const [rows, setRows] = useState([])
  const [error, setError] = useState('')
  const [accessToken, setAccessToken] = useState('')
  const [accountName, setAccountName] = useState('')
  const [checkingSession, setCheckingSession] = useState(authConfigured)
  const empty = { prompt:'', options:['','','',''], correct_index:0, explanation:'', category:'science', difficulty:'easy' }
  const [form, setForm] = useState(empty)

  async function load(token) {
    try {
      setRows(await request('/api/admin/questions', {}, token))
      setError('')
    } catch (e) {
      setError(e.message)
    }
  }

  useEffect(() => {
    let active = true

    async function restore() {
      if (!authConfigured) {
        if (active) setCheckingSession(false)
        return
      }
      try {
        const session = await existingAdminSession()
        if (!active || !session) return
        setAccessToken(session.accessToken)
        setAccountName(session.account?.username || session.account?.name || '')
        const data = await request('/api/admin/questions', {}, session.accessToken)
        if (active) setRows(data)
      } catch (e) {
        if (active) setError(e.message)
      } finally {
        if (active) setCheckingSession(false)
      }
    }

    restore()
    return () => { active = false }
  }, [])

  async function login() {
    try {
      setError('')
      const session = await signInAdmin()
      setAccessToken(session.accessToken)
      setAccountName(session.account?.username || session.account?.name || '')
      await load(session.accessToken)
    } catch (e) {
      setError(e.message)
    }
  }

  async function logout() {
    try { await signOutAdmin() } catch (e) { setError(e.message) }
    setAccessToken('')
    setAccountName('')
    setRows([])
  }

  async function add(e) {
    e.preventDefault()
    try {
      await request('/api/admin/questions', { method:'POST', body:JSON.stringify(form) }, accessToken)
      setForm(empty)
      await load(accessToken)
    } catch (e) { setError(e.message) }
  }

  async function remove(id) {
    try {
      await request(`/api/admin/questions/${id}`, { method:'DELETE' }, accessToken)
      await load(accessToken)
    } catch (e) { setError(e.message) }
  }

  if (checkingSession) return <p>Checking admin session…</p>

  if (!authConfigured) {
    return <>
      <h2>Admin — Questions</h2>
      <p className="error">Admin sign-in is not configured for this environment.</p>
    </>
  }

  if (!accessToken) {
    return <>
      <h2>Admin — Questions</h2>
      <p>The quiz is public. Sign in only to manage questions.</p>
      {error && <p className="error">{error}</p>}
      <button onClick={login}>Sign in with Microsoft Entra</button>
    </>
  }

  return <>
    <div className="toolbar">
      <strong>Admin — Questions</strong>
      <span>{accountName || 'Signed in'} <button onClick={logout}>Sign out</button></span>
    </div>
    {error && <p className="error">{error}</p>}
    <form className="card" onSubmit={add}>
      <input placeholder="Question" value={form.prompt} onChange={e=>setForm({...form,prompt:e.target.value})} required/>
      {form.options.map((x,i)=><input key={i} placeholder={`Option ${i+1}`} value={x} onChange={e=>{const o=[...form.options];o[i]=e.target.value;setForm({...form,options:o})}} required/>)}
      <input type="number" min="0" max="3" value={form.correct_index} onChange={e=>setForm({...form,correct_index:Number(e.target.value)})}/>
      <textarea placeholder="Explanation" value={form.explanation} onChange={e=>setForm({...form,explanation:e.target.value})} required/>
      <button>Add question</button>
    </form>
    {rows.map(r=><div className="admin-row" key={r.id}><span>{r.id}. {r.prompt}</span><button onClick={()=>remove(r.id)}>Delete</button></div>)}
  </>
}

export default function App() {
  const [page, setPage] = useState('quiz')
  return <main><nav><button onClick={()=>setPage('quiz')}>Quiz</button><button onClick={()=>setPage('admin')}>Admin</button></nav>{createElement(page === 'quiz' ? Quiz : Admin)}</main>
}
