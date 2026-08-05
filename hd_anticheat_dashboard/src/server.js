require('dotenv').config();
const path = require('path');
const express = require('express');

require('./db'); // opens the DB and applies schema.sql before anything else touches it

const app = express();
app.use(express.json());

app.use('/api/auth', require('./routes/auth'));
app.use('/api', require('./routes/config'));
app.use('/api', require('./routes/webhook'));
app.use('/api', require('./routes/bans'));
app.use('/api/uploads', require('./routes/uploads'));
app.use('/api/admin', require('./routes/admin'));

app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));
app.use(express.static(path.join(__dirname, '..', 'public')));

const port = process.env.PORT || 3050;
app.listen(port, () => {
    console.log(`[hd_anticheat_dashboard] listening on http://localhost:${port}`);
});
