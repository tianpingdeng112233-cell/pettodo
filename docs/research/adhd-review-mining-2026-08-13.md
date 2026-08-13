# ADHD app 评论扫描 · 机会点与避坑

**日期：** 2026-08-13 ｜ **配套：** [竞品快照](adhd-competitive-snapshot-2026-08-13.md)（同日）、[Reddit 痛点调研](adhd-app-painpoints-reddit-2026-08-13.md)、[ADHD 人群痛点](adhd-people-painpoints-reddit-2026-08-13.md)

## 0. 数据来源与覆盖（先说清楚拿到了什么、没拿到什么）

| 来源 | 状态 | 实际拿到 |
|---|---|---|
| Apple App Store 评论 RSS（美区，最新排序） | ✅ 通 | **1154 条全文**：Finch 400 / Tiimo 350 / Numo 254 / Habitica 150 |
| Google Play 评论（美区，`google-play-scraper`） | ✅ 通 | **3600 条全文**：Finch 1612 / Habitica 1537 / Numo 339 / Tiimo 112 |
| Reddit | ✅ 通（走 David 本机 Chrome） | r/ADHD **3 个新帖全文 + 评论区**（另有 7 帖沿用今日已跑的两份调研）。前三条路——curl JSON 403 / 内置浏览器策略拦 / WebFetch 拒绝——**全部失败**，最终是用户授权直控 Chrome 才拿到 |

**合计 4754 条商店评论 + 10 个 Reddit 帖。**

> Reddit 采集说明：只读浏览，未登录、未交互、未发帖。old.reddit 需要登录，**未走**（不碰登录）。

> ⚠️ **两条采样口径必须记住，否则会读错下面所有百分比：**
> ① Apple RSS 按**最新**排序 —— 反映「当前状态」，不是历史累积评分，两者背离本身就是信号。
> ② Google Play 侧我**刻意超采了低分**（每家在 800 条最新之外，额外抓 400×1★ + 300×2★ + 200×3★）。所以 **Play 的主题占比是「痛点浓度」而非「总体分布」**，只可用于横向对比同一列内的主题排序，不可当作「x% 的用户遇到此问题」。Tiimo 因 Android 侧评论总量本就不足，只拿到 112 条，**其百分比不具统计意义，仅作定性参考**。

---

## 1. 双端规模对比：Android 侧格局与 iOS 完全不同

| App | iOS 评分数 / 星级 | **Play 装机量** | Play 评分数 / 星级 | 双端落差 |
|---|---|---|---|---|
| **Finch** | 739K / 4.9★ | **10,000,000+** | 610K / **4.88★** | 无落差，双端都是碾压级 |
| **Habitica** | 3.1K / 4.2★ | **5,000,000+** | 74.8K / **4.67★** | **Android 侧强得多**（评分数 24 倍、星级更高） |
| **Tiimo** | 19K / 4.6★ | **50,000+** | 1.8K / 4.57★ | **Android 侧近乎不存在**（评分数只有 iOS 的 1/10） |
| **Numo** | 1.1K / 4.4★ | **50,000+** | 1.1K / **3.29★** | **Android 侧口碑崩盘**（3.29★，198/339 是 1★） |

三条对 PetTodo 直接有用的结论：

1. **Tiimo 是个 iOS 现象，不是跨端强者。** Apple 年度应用的光环全在 iOS；Android 侧 5 万装机、1766 条评分——**「ADHD 视觉规划」在 Android 上没有强者**。PetTodo 双端同发（07-20 拍板）在 Android 侧撞见的对手，实际上只有 Finch 和 Habitica。
2. **Habitica 在 Android 的地位远高于 iOS**（4.67★ vs 4.2★，500 万装机）。惩罚机制在 Android 用户里没有被同等惩罚——说明「掉血劝退」这个判断在 iOS 侧成立，不能直接外推到 Android。
3. **Numo 的 Android 版是已经烧掉的品牌。** 3.29★ 且 41% 的评论命中收费争议。它在两端都没守住「cringe-free」这个位。

---

## 2. 评分分布：三个反常信号

| App | 近期样本 | 5★ | 1★ | 1★ 占比 | 商店累积评分 | 背离 |
|---|---|---|---|---|---|---|
| Finch | 400 | 336 | 19 | 4.8% | 4.9★ | 一致，口碑真实 |
| **Tiimo** | 350 | 137 | **100** | **28.6%** | 4.6★ | **严重背离** |
| **Numo** | 254 | 110 | **73** | **28.7%** | 4.4★ | **严重背离** |
| Habitica | 150 | 83 | 15 | 10.0% | 4.2★ | 略好于累积 |

**信号一：Finch 的 4.9★ 是真的。** 近期 1★ 只占 4.8%，与累积评分一致——这不是刷出来的评分，「宠物养成绑自我照顾」这条路的市场验证是硬的。

**信号二：Tiimo 正在掉。** Apple 年度应用、4.6★ 的累积口碑下，近期近三成 1★。低分高频词：tasks(60)、calendar(37)、free(25)、trial(24)、subscription(19)、**useless(18)**、cancel(17)。原文样本：「an all but useless AI assistant means I'm stuck trying to figure out every single thing manually」（1★ v3.62.0）；「it doesn't know I'm subscribed? The widgets won't work correctly」（2★）；还有大量「找不到取消入口」。

**信号三：Numo 的问题不是产品，是收费。** 低分高频词 top：subscription(54)、**cancel(51)**、free(52)、trial(46)、**charged(41)**、refund(14)。全量 254 条里 **29% 命中订阅争议，其中 68 条是低分**。原文：「Stealing money... charged over 100 dollars a month」「$90 CHARGE AFTER DELETING MY ACCOUNT」「After a trial, I canceled this but was charged anyway」。

> **这条直接修正快照里的 Risk 1。** 我上一份快照判断「Numo 已占 cringe-free 心智，PetTodo 要正面对撞」——评论证据显示这个占位**是虚的**：它有正确的定位语，但正在用暗黑订阅模式烧掉信任（1.1K 评分规模 + 29% 收费投诉）。**「成人向、不幼稚的 ADHD 陪伴 app」这个位子实质上仍然空着**，Numo 只是名义上站着。

---

## 2.5 Reddit 补充：商店评论看不到的三件事

商店评论是「已经在用的人」写的，Reddit 是「用过又走了的人」写的——后者才有弃用机制。三个新帖：

### ① 弃用机制被用户自己描述得比任何分析都准

[be honest - do any of you actually USE your task apps...](https://www.reddit.com/r/ADHD/comments/1q8co2q/)（170↑ / 108💬，7 个月前）。OP 开篇就是「**刚第三次删掉 Tiimo**」，然后精准描述了循环：

> 「I set it up when I'm **hyperfocused**, add like 47 tasks with color coding and everything, use it for maybe **4 days**, then one morning I wake up and **the app feels like my disappointed mother** so I just… stop opening it. And then **I feel guilty about the app I downloaded to stop feeling guilty about tasks.**」

评论区给出了这个状态的名字，OP 当场认领：

> 「when I lose momentum they become a **shame reminder** of how "behind" I feel」
> OP 回复：「**Shame reminder is exactly the phrase I was looking for.** It's like **the app is judging me** for the overdue tasks, so I just **avoid opening it entirely**.」

**→ 这是 PetTodo 红线③的真正对手。** 不是「惩罚」，是**积压本身在说话**——未完成的任务堆在那里，就构成指责。零惩罚不等于零指责：只要打开 app 会看到一片没做完的东西，它就是那个 disappointed mother。**「宠物零惩罚」是必要不充分条件，还得让「久未打开后的第一屏」不指责人**（这条直连 08-13 待拍板 ①：长期缺席后的状态语义）。

### ② 在这个「app 坟场」帖里，Finch 是唯一被反复点名「活下来了」的

同一帖里，一堆人报出真实天数——**这是 Finch 留存的最强外部证据，比商店评分更硬**：

> 「The only one that has stuck for me is Finch... and I think because **it's not so much a productivity app and more of a self care app**」
> 「I made it over **300 days**.. my son is on day 350! **Gotta take care of that birb.**」
> 「I'm on a **580 day streak**... my bird just turned 2. ... And I love that **you can pause it without losing your streak** if you need to.」
> 「Finch has definitely been the only to stick for me too. I've been using it **for years**」
> 反例也在：「I downloaded finch and **haven't opened it a single time** since.」

两条可直接抄的机制：
- **「不是生产力工具，是自我照顾工具」** ——用户自己给出的归因。品类站位决定了它不进「productivity app 坟场」那个心理抽屉。
- **可暂停且不丢 streak** ——Finch 把「休息」做成了产品功能而不是失败状态。PetTodo 目前是「正向历史无 streak」（更激进），但**「主动暂停」这个动作本身值得有**：它把缺席从「我失败了」重写为「我决定的」。

### ③ 宠物机制的**有效边界**：只对小的日常维护有效，对大任务无效

[I tried the Finch app for ADHD](https://www.reddit.com/r/ADHD/comments/1p1aj6t/)（9 个月前）——一位用户第 8 天的详细自述：

> 「**I don't use it for big goals.** Those are things that I have to tackle in a particular way, and **being rewarded by buying clothes for a virtual bird isn't enough motivation** to do them.」

他实际放进去的全是：喝完一瓶水、从工位站起来、早晚拉伸、洗漱分步（刷牙/洗脸/涂乳液）、吃药、周三给猫刷牙。然后讲了机制：

> 「the app is so colorful and cute that it feels like a game I have to check in on, so **I find myself just opening it during the day to see the little bird**, which means **I'm seeing those reminders all the time!**」

**→ 两条对 PetTodo 的直接结论：**
1. **D17 拍板（todo 止步及格线、不做项目/子任务/看板）现在有了机制解释**，不只是「功能克制」——宠物奖励在大任务上**本来就无效**，做进去是浪费。1-7 条日常正好是它起作用的区间。
2. **「打开理由」问题有答案了**：用户是为了**看宠物**才打开，任务提醒是搭便车看到的。这直接回答我上一版报告里的待验证假设③（零配置会不会让用户失去打开理由）——**宠物本身就是打开理由**，前提是它值得一看（会变化、会说话）。

**⚠️ 但同一帖也暴露了真正的坎：新颖性衰减，且不在两周。**
> OP 自陈：「I've actually tried Finch before and **failed after like 2 days** and deleted it」，且承认现在「still in the window for my fixation on something shiny and new to wear off」
> 评论：「I managed to stick to using it for **around 2 months** and then I suddenly stopped **for no reason**... I guess **the novelty wore off**.」

**→ 行业判据「两周留存 >50%」可能过于宽松。** 真实的死亡区间有两个：**第 2–4 天**（设置完热情退潮）和**第 2 个月**（新鲜感耗尽）。PetTodo 的北极星目前锚在第二周留存——**建议加测第 60 天**，否则会把「还没到衰减期」误读成「验证通过」。

### 附带发现：幼齿感的第二个独立证据，以及一批 quest 派竞品

[do you know any apps that gamify every day life?](https://www.reddit.com/r/ADHD/comments/1oef2dt/)：
> 「**finch was nice but felt a bit too cute for him**, he wanted something that feels **more like a game than a pet simulator**.」
> 换用 Hyper（sidequest 制）后：「he started completing the quests cause it felt like **leveling up, not being told what to do**.」

评论区还点了 **TaskHero**（世界地图/任务线/怪物/坐骑）、**LifeUp Pro**（自定义奖励）、Habitica。

**→ 这是快照四象限里漏掉的一派：quest/adventure 派。** 它们和 Finch 争的是同一批人，卖点是「升级感而不是被指使感」。PetTodo 若走「成人向可爱」，要同时区别于 Finch（太幼）和 quest 派（太游戏）——**「陪伴」是第三条路，但必须说得出它凭什么比升级更持久**。快照的竞品集下一轮该把 Hyper 补进来（当前证据等级：低，仅一个二手提及）。

---

## 3. 机会点（每条带证据）

### 机会 1 · 「双向照顾」是 Finch 被用户自己复述出来的核心机制，且远未做满

Finch 400 条评论里 **117 条（29%）主动出现情感联结语言**（my birb / companion / attached / comfort）——对照组：Tiimo 12%、Habitica 13%、Numo 9%。用户原话把机制讲得比 Finch 官网还清楚：

> 「You can take care of your pet, and then **your pet takes care of you**!」（5★）
> 「I struggle with remembering to do my stuff but after I got finch **I wanted to help my birb, puff**! Now I get all my stuff done every day.」（5★）

**但 Google Play 有人明确指出它不够：**
> 「The ad claimed it was **like a tamagotchi, but it isn't really**. That would actually be cool though.」

→ **对 PetTodo：** 情感机制是已验证的引擎，且天花板未到。PetTodo 的养成 2.0（成长阶段/摸一摸/作息/小剧场）方向正确，「比 Finch 更像真的养宠」是可打的差异化，而不是要另辟蹊径。

### 机会 2 · ADHD 用户会主动表扬「不让我内疚」——零惩罚是可对外说的卖点，不只是内部红线

> 「**For my ADHDers** I'm on day 32 and still strong. This **doesn't make you feel guilty if you missed**, the dopamine of the gems and the little noise it makes when you complete it gives me so much dopamine.」（5★）

对照 Habitica 的 3★ 原文：
> 「How did the entire dev team think that **stripping players of their LEVELS** when dying to a boss was good idea?? ... it's absurd to lose your LEVEL just because you died to the boss.」

→ **对 PetTodo：** 红线③（宠物零惩罚）目前是内部工程约束，评论证据说明它**值得升格为对外定位主张**——ADHD 用户认得出这个差别，并会主动写进好评里。

### 机会 3 · 「反成瘾」被当成优点，与 ADHD 人群的自我认知对齐

> 「**Not as addictive as other "self-care" apps.** I feel encouraged to **take time away from the app** (letting my finch explore, finishing my tasks, and running out of things to do) and my phone by extension.」（5★）

→ **对 PetTodo：** 「用完就走、宠物在你不看时自己过得好」既守零惩罚红线，又是差异化文案角度，且正面回应 08-13 调研暴露的「拟人化制造情感债务」那个洞——**宠物不需要你，它只是喜欢你回来**。

### 机会 4 · Tiimo 的通知痛点是整条「视觉日程」路线的漏水口

Tiimo 350 条里 **59 条（16%）命中通知问题，其中 35 条是低分**（四家里通知负面率最高）。叠加已有调研 F3：「app 告诉我该换衣服出门了，我知道它是对的，然后我说『再等一分钟』」。

→ **对 PetTodo：** 提醒的载体是**一只等你的宠物**而不是一条日程通知，这正是「告知≠启动」的第三条路（外部性驱动，非情绪施压）。已有调研给的三条工程解法可直接抄：提醒措辞每次变化 / 触发时间加随机抖动 / 连续忽略后指数退避。

---

### 机会 5 · ⭐ Task 002（常驻层）拿到了直接的需求证据——而且不是「日程条」，是「宠物主动说话」

Play 上一条 5★ 原文，把 Task 002 的价值讲得比任何内部论证都清楚：

> 「I feel like I can function. I was feeling down and i hadn't used the app in a few days, **the widget on my screen showed my bird telling me we can fix this** and it sent me into productivity mode on a day where I would have gotten nothing done.」（5★）

> 「great app if you want to stick to your goals **if you put the widget on your home screen** and turn notifications on」（5★）

注意机制：起作用的不是「widget 显示了任务列表」，而是**宠物在用户没打开 app 的时候主动开口**，把一个已经放弃的一天拉回来。这正好对上 08-13 调研的两条硬约束——「眼不见即不存在」＋「只有外部性驱动才有效，情绪施压无效」。

→ **对 PetTodo：** Task 002 的产品定义应该写成「**宠物住在桌面上，并且会在你消失时开口**」，而不是「常驻的任务清单」。这也是与 Tiimo（widget 显示日程）的差异所在。⚠️ 同时抓到技术风险，见坑 6。

---

## 4. 避坑（每条带证据，按严重度排）

### 🚨 坑 1（最高危）· 宠物存档损坏 = 情感产品的死亡开关，而 PetTodo 的架构风险比 Finch 更高

Finch 的持续事故，用户原文：
> 「It is a **KNOWN BUG THAT YOUR PET FILES CAN GET CORRUPTED**, and all you get is a few pieces of candy thrown in your face as 'oh! Sorry for the inconvenience'」（1★）
> 「They have very horrible bugs that make you **lose your Birb's progress and items and you have to start from scratch**. Happened to me this July. It's happening to multiple users more and more frequently. **My Birb is almost a year old. Some are 5+ years old.**」（1★）
> 「it just kicked me out of my profile... I ended up creating a new profile and **I lost all of my progress**」（4★，仍给四星，但人已经走了）
> 「**Loved it until I got a new phone.** It logged me out and now I can't log back in」（2★）

**Android 侧证据更硬——这是 Play 上按点赞排序的头部投诉**（Finch 1612 条里 58 条命中，其中 45 条是 1-2★）：

> 「**I lost ALL of my items after using this app for over a year** and collecting so much. One day, everything was just gone. I logged out and back in, but nothing changed. **Support blamed the backup file, but I never changed phones and the app is supposed to back up data automatically.**」（1★ 👍15，2026-06-11）
> 「**all my data from the past 2 years of playing is corrupt and gone. im not starting over.** I did all the troubleshooting and nothing. **my data was backed up so idk what happened** 😐」（2★ 👍12，2026-05-12）
> 「it keeps freezing and the only fix is uninstalling. This wouldn't be so bad, except **I lose a lot of data since it won't allow me to create a manual backup**.」（2★ 👍13，2026-02-11）

⚠️ 最后一条是本次扫描里对 PetTodo 最有指导性的一句：**用户明确在要一个「手动备份」按钮，而 Finch 没给**——它只有自动云备份，而自动备份恰恰是出事时最不可信的那一环（前两条都是"我明明备份了"）。

**为什么这对 PetTodo 更致命：** 宪法④规定 concierge MVP **无后端、纯本地**。这意味着今天的 PetTodo：换手机 = 宠物没了；重装 = 宠物没了；手机丢了 = 宠物没了。Finch 至少有账号体系还能试着找回。**而 PetTodo 的整个价值主张建立在「这是你自家的宠物」——情感投入越深，丢失的伤害越大，且 008 之后宠物是用户自己的真宠物照片孵的，不可替代。**

→ **行动（建议 P0 级，不上发版线也要先做）：** 本地导出/导入已经有了（`.pettodopet` 包 + share sheet，008 已实装）——**把它从「concierge 运营通道」升格为面向用户的「宠物备份」功能**，加一条「你的宠物只存在这台手机上，导出一份存好」的引导。这不违反无后端约束，是纯本地能力的重新包装，成本极低。同时把「覆盖导入 / 换机恢复」纳入验收清单（008 残办里 Android SAF 导入未 UI 验证，正是这条链）。

### 🚨 坑 2 · 加社交会让老用户觉得「这 app 不再是为我做的」

> 「**Sad it's not built for me anymore.** It used to be very useful, but it's been **turned into a social focused app** that no longer suits me and my needs.」（1★）
> 「They keep **removing features instead of improving** the ones they already have. Why do people pay for plus, again?」（1★）

Finch 社交相关评论 46 条（11%），其中 6 条低分——占比不高，但**流失的是深度用户**（原文都是「用了很久」的人）。

→ **对 PetTodo：** 社交/好友/排行不在当前路线里，**保持不在**。若未来考虑，先问「这解决哪个具体 ADHD 问题」（宪法功能门）——社交攀比对 rejection sensitivity 人群是负分。

### 🚨 坑 3 · 订阅暗黑模式是这个品类的信任杀手，且四家都在踩

Numo 29% 评论命中收费争议（68 条低分）；**连 Finch 都有**：
> 「I downloaded the app about 3 weeks ago and was using the free version. Today I was surprised to find out that my Apple account was **charged $35 for a yearly subscription that I did not authorize**.」（1★）

Tiimo 同样有大量「找不到取消入口」。Numo 的 App Store 页并列 $7.99/$9.99/$15.99 三种月费——Google Play 评论直指：「**$15 per month is more than most people are going to want to pay for an adhd app.**」

→ **对 PetTodo：** ADHD 人群对订阅陷阱的敏感度和受害率都高于普通人群（执行功能障碍 = 忘记取消），且他们会把这件事写进评论里长期传播。**变现设计上：取消入口显眼、试用到期前主动提醒、绝不用暗黑模式**——在这个品类里这不是道德加分，是可防御的差异点。

### 坑 4 · 付费墙别切在「审美自定义」上

Finch 的 2★：「You can't really enjoy it without upgrading to premium. The clothing options if you don't pay are usually just **basic and kinda ugly**」；另一条 1★：「**Why am I paying for fewer options?**」（Plus 用户抱怨改版后颜色选项反而变少）。Habitica 3★：「**Pay to win** — if you want to collect all the pets, you have no choice but to subscribe」。

→ **对 PetTodo：** 宠物的外观/装扮如果是情感联结的载体，把它锁在付费墙后会直接削弱核心机制。付费点应该切在**别处**（更多宠物位、孵化加速、导出/纪念品），不是切在「让你的宠物好看」。

### 坑 5 · 幼齿感在评论区是低频，但在 Reddit 是高频——它是获客问题不是留存问题

App Store 评论里「幼齿/审美」只命中 11 条（Finch 2%），但 r/ADHD 有整条热帖叫 "App like Finch, but not infantile?"（109↑ 附议）。

→ **解读：** 觉得幼齿的人**根本不会下载，也就不会留评论**——评论区天然幸存者偏差。所以别用商店评论低频来判断这个问题不严重。**它决定的是有多少 ADHD 成人愿意开始用**，正是 PetTodo 现在要打的那部分人。

---

### 🚨 坑 6（Android 特有，直接命中 Task 002）· 定时提醒与 widget 刷新在 Android 上是全品类烂账

**Habitica 的通知问题是长达数年的公开伤口**，且这些差评至今仍是点赞榜首（说明问题没修好）：

> 「Tried it for a week, but **fails at the critical core function** of a habit building/task app — **Can't provide consistent reminder notifications at scheduled times! Seems like a known issue**」（2★ 👍48）
> 「I don't get a single notification at the time I scheduled them for. I turned off battery saver and another setting to actually get the notifications to pop up at all, but **they come 3–16 minutes late**」（1★ 👍33）
> 「I'm not receiving any notifications until I actually open the app up to check it. **Then I'll get pinged with a lot of notifications at once which can get very overwhelming.**」（2★ 👍34）

Habitica 1537 条里 111 条命中通知，其中 63 条 1-2★——是它 Android 侧的头号痛点。**Finch 的 widget 也中招：**

> 「I have issues with **the widgets not updating** to remind me to check in for the day, **which might be due to my battery saver being on**」（3★）

→ **对 PetTodo（Task 002 施工前必须处理）：**
① Android 的 OEM 省电策略（小米/华为/OPPO/三星各家不同）会杀掉后台刷新与定时通知，**这是「宠物在桌面上活着」这个卖点的物理天敌**——一只不动、不说话的宠物比没有更糟；
② 最后一条原文暴露的失败模式尤其危险：**通知积压后一次性轰炸**，对 ADHD 用户是直接的过载劝退；
③ PetTodo 已有前科——07-22 的 Android 黑屏事故根因就在通知初始化（`ic_notification` 被 release 资源缩减剔除）。已立的纪律（每个包双端各真启动一次）要延伸到**通知与 widget 的真机时序验证**，而不只是「能启动」。

---

## 5. 给 PetTodo 的直接行动项

| # | 行动 | 依据 | 建议档位 |
|---|---|---|---|
| 1 | `.pettodopet` 导出升格为用户可见的「宠物备份」+ 引导文案；换机恢复纳入验收 | 坑 1（Finch 存档损坏事故 + PetTodo 无后端） | **P0-ish**，成本极低 |
| 2 | 零惩罚从内部红线升格为对外定位主张（App Store 副标题/首屏文案） | 机会 2（ADHD 用户主动表扬「不让我内疚」） | P1 |
| 3 | 提醒三件套：措辞每次变化 / 触发时间抖动 / 连续忽略指数退避 | 机会 4（Tiimo 通知负面率 16% 最高） | P1 |
| 4 | 变现设计立「反暗黑模式」纪律；付费墙不切在宠物外观上 | 坑 3、坑 4 | 拍板前置 |
| 5 | 社交功能保持不做；若提案必须过 ADHD 功能门 | 坑 2 | 纪律 |
| 6 | 「不幼稚」的成人向美学仍是获客关键，且 Numo 两端都没真正占住 | 信号三 + 坑 5 + §1 | **待拍板** |
| 7 | Task 002 产品定义改写为「宠物住桌面 **且会在你消失时开口**」，不是常驻任务清单 | 机会 5（widget 5★ 原文） | 施工前 |
| 8 | Task 002 施工前先解 Android 省电策略 / 通知积压两个技术风险，并把「通知与 widget 真机时序验证」写进验收 | 坑 6（Habitica 数年烂账 + Finch widget 不刷新 + 07-22 黑屏前科） | **施工前置** |
| 9 | **「久未打开后的第一屏」单独设计并纳入验收**——零惩罚 ≠ 零指责，任务积压本身就在说话 | §2.5① "disappointed mother" / "shame reminder" | **P1，直连待拍板①** |
| 10 | 加一个**主动「暂停」**动作（把缺席从「我失败了」重写为「我决定的」） | §2.5② Finch 可暂停不丢 streak | P1 |
| 11 | 北极星**加测第 60 天留存**，不能只看第二周 | §2.5③ 两个死亡区间：第 2–4 天、第 2 个月 | **口径修订** |
| 12 | 竞品集补 quest 派（Hyper / TaskHero / LifeUp Pro）——与 Finch 争同一批人 | §2.5 附带发现 | 下轮快照 |

---

## 6. 证据缺口与后续

**已补齐：** Google Play 3600 条正文 + 四家装机量/星级（Android 侧痛点分布已成样本）；Reddit 3 个新帖全文+评论区（弃用机制、Finch 真实留存天数、宠物机制有效边界）。

**仍缺：**
- **Reddit 采集只能靠 David 本机 Chrome**——curl/内置浏览器/WebFetch 三条自动化路径全被挡，意味着这部分**无法排进 `competitive-intel-watch` 的无人值守定期扫描**。要么每次人工开一次 Chrome，要么申请 Reddit 官方 API key。
- **quest 派竞品（Hyper / TaskHero / LifeUp Pro）零调研**——仅一条二手提及，证据等级低。它们与 Finch 争同一批人，且正好卡在 PetTodo「成人向但不游戏化」的定位缝隙上，下轮快照该补。
- **Tiimo 近期 1★ 潮的根因**未定位（版本更新翻车？还是订阅策略变更？）。iOS 侧近 350 条里 28.6% 是 1★，而 Android 侧样本太少（112 条）无法交叉验证。若是改版翻车 → 对 PetTodo 是可趁的窗口；若是长期趋势 → 说明「视觉日程」路线整体退潮。**建议用 `competitive-intel-watch` 挂定期盯，这是本次唯一值得持续监控的变量。**
- **Habitica 的 iOS/Android 口碑倒挂**（4.2★ vs 4.67★）未解释。若能定位原因，等于拿到「同一套惩罚机制在两个平台人群里反应不同」的天然实验——对 PetTodo 判断「零惩罚是不是普适卖点」有直接价值。

---

## 附：数据与可复现

原始数据落在会话 scratchpad：`apple_reviews.json`（1154 条）、`play_reviews.json`（3600 条 + 四家 meta）。抓取脚本 `fetch_apple.py`（Apple 官方 RSS，无需 key）、`fetch_play.py`（`google-play-scraper`）。包名：`com.finch.finch` / `com.tiimo.androidappreactnative` / `com.habitrpg.android.habitica` / `io.mindist.well`。⚠️ scratchpad 是会话级临时目录，要留就得挪进 repo。
