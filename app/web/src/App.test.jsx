import { describe, expect, it } from 'vitest'

describe('quiz app', () => {
  it('has a deterministic smoke assertion', () => {
    expect('quiz_app').toContain('quiz')
  })
})
