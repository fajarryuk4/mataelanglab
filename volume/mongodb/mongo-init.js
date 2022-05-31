db = db.getSiblingDB('mataelanglab');

db.createCollection('netflowmeter');
db.createCollection('snorqtt');
db.createCollection('ml_model');
db.createCollection('ml_duration');
db.createCollection('ml_result');
db.createCollection('ml_cv_result');