begin;
select plan(2);
select has_schema('public', 'TC1: public schema exists');
select has_schema('extensions', 'TC1: extensions schema exists');
select * from finish();
rollback;
