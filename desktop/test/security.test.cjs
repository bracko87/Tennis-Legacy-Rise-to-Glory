'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { isGameUrl, isExternalUrl } = require('../security.cjs');

test('game host permits only HTTPS and canonical hosts', () => {
  assert.equal(isGameUrl('https://www.tennislegacygame.com/game/dashboard'), true);
  assert.equal(isGameUrl('https://tennislegacygame.com/login'), true);
  assert.equal(isGameUrl('http://www.tennislegacygame.com/'), false);
  assert.equal(isGameUrl('https://tennislegacygame.com.evil.example/'), false);
  assert.equal(isGameUrl('file:///etc/passwd'), false);
  assert.equal(isGameUrl('javascript:alert(1)'), false);
  assert.equal(isGameUrl('https://user:pass@tennislegacygame.com/'), false);
});

test('external links only allow safe schemes', () => {
  assert.equal(isExternalUrl('https://checkout.stripe.com/x'), true);
  assert.equal(isExternalUrl('mailto:support@example.com'), true);
  assert.equal(isExternalUrl('file:///tmp/test'), false);
  assert.equal(isExternalUrl('javascript:alert(1)'), false);
});
