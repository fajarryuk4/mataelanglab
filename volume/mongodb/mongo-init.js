db = db.getSiblingDB('mataelanglab');

db.createCollection('netflowmeter');
db.createCollection('snorqtt');

db.createCollection('sklearn_result');
db.createCollection('sklearn_cv');

db.createCollection('spark_result');
db.createCollection('spark_cv');

db.createCollection('stream_result');
