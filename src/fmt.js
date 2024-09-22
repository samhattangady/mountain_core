let values = `
0	0	0	1080	90	270	200	600	2000	15000	10000000
30	6	18	1728	171	405	560	18446744073709500000	3400	33000	18446744073709500000
62	14	40	2765	325	608	1568	18446744073709500000	5780	72600	18446744073709500000
129	33	89	4424	617	911	4390	18446744073709500000	9826	159720	18446744073709500000
266	77	197	7078	1173	1367	18446744073709500000	18446744073709500000	16704	18446744073709500000	18446744073709500000
551	176	437	18446744073709500000	2228	2050	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000
1140	405	971	18446744073709500000	4234	3075	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000
2360	933	2155	18446744073709500000	8045	4613	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000
4886	2145	4783	18446744073709500000	18446744073709500000	6920	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000
10113	4934	10619	18446744073709500000	18446744073709500000	10380	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000
18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000
18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000
18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000
18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000
18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000
18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000
18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000
18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000
18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000
18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000	18446744073709500000
`;
values=values.split("\n");
for (let i=1; i<21; i++) {
  values[i] = values[i].split("\t");
}
let zig_str = "\npub const UPGRADE_COSTS = [_][20]u64{\n";
for (let i=0; i<11; i++) {
  zig_str += ".{";
for (let j=1; j<21; j++) {
  zig_str += values[j][i];
  zig_str += ",";
}
zig_str = zig_str.slice(0,zig_str.length-1);
  zig_str += "},\n";
}
  zig_str += "};\n";
//console.log(zig_str);
const fs = require('node:fs');
const content = zig_str;
fs.writeFile('src/upgrade_costs.zig', content, err => {
  if (err) {
    console.error(err);
  } else {
    // file written successfully
  }
});
