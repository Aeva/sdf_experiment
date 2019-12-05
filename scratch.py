
from math import *


dont_care = 0.001


def dot(lhs, rhs):
    acc = 0
    for a, b in zip(lhs, rhs):
        acc += a * b
    return acc


def length(vec):
    return sqrt(dot(vec, vec))


def add(lhs, rhs):
    return tuple([a + b for a, b in zip(lhs, rhs)])


def sub(lhs, rhs):
    return tuple([a - b for a, b in zip(lhs, rhs)])


def div(vec, d):
    return tuple([s / d for s in vec])


def mul(vec, d):
    return tuple([s * d for s in vec])


def distance(lhs, rhs):
    return length(sub(rhs, lhs))


def normalize(vec):
    return div(vec, length(vec))


def sdf_sphere(point, radius):
    return length(point) - radius


def sdf_box(point, extent):
    fnord = sub(map(abs, point), extent)
    return length([max(i, 0) for i in fnord]) + min(max(*fnord), 0.0)


def translate(point, offset):
    return sub(point, offset)


def sdf_union(*sdfs):
    return min(*sdfs)


def sign(n):
    return -1 if n < 0 else 1


def pretty_float(ok_float):
    return floor(abs(ok_float) * 10000000) / 10000000.0 * sign(ok_float)


class sample:
    def __init__(self, tx, sd):
        self.tx = tx
        self.sd = sd
    def __repr__(self):
        return "(tx: {}, sd: {})".format(self.tx, self.sd)


def next_tx(samples, t_start, t_end):
    dont_care = 0.001
    nearest = samples[0].tx - abs(samples[0].sd)
    if nearest > (t_start + dont_care):
        #print("search: gap at front")
        return nearest * 0.5, 0
    
    if len(samples) > 1:
        for i in range(len(samples)-1):
            lhs = samples[i]
            rhs = samples[i+1]
            low = lhs.tx + abs(lhs.sd)
            high = rhs.tx - abs(rhs.sd)
            if ((low + dont_care) < high):
                #print("search: gap between {} and {}".format(i, i+1))
                return (high-low) * 0.5 + low, i+1
            elif lhs.sd < dont_care:
                return None, i
            elif rhs.sd < dont_care:
                return None, i+1

    farthest = samples[-1].tx + abs(samples[1].sd)
    if (farthest + dont_care) < t_end:
        #print("search: gap at end")
        return (t_end - farthest) * 0.5 + farthest, -1

    return None, None


def search(ray_start, ray_end, ray_dir, sdfn):
    t_start = 0
    t_end = distance(ray_end, ray_start)
    t_mid = t_end * 0.5

    def new_sample(tx):
        global sample
        pos = add(ray_start, mul(ray_dir, tx))
        sdf = sdfn(pos)
        return sample(tx, sdf)

    samples = [new_sample(t_mid)]
    t_next, param = next_tx(samples, t_start, t_end)

    while t_next is not None:
        fnord = new_sample(t_next)
        if param == -1:
            samples.append(fnord)
        else:
            samples.insert(param, fnord)
        t_next, param = next_tx(samples, t_start, t_end)

    hit = None
    if param is not None:
        t_hit = samples[param].tx + samples[param].sd
        hit = new_sample(t_hit)

    return "NEW", samples, hit


class coverage:
    def __init__(self, tx, sd):
        global dont_care
        if sd is None:
            self.low = tx
            self.high = tx
            self.sign = 0
        else:
            self.low = tx - abs(sd)
            self.high = tx + abs(sd)
            self.sign = -1 if sd < dont_care else 1

    def __repr__(self):
        return "({} -> {}: {})".format(self.low, self.high, self.sign)


def search2(ray_start, ray_end, ray_dir, sdfn):
    global dont_care
    t_start = 0
    t_end = distance(ray_end, ray_start)
    t_mid = t_end * 0.5

    pos_at_t = lambda t: add(ray_start, mul(ray_dir, t))
    sd_at_t = lambda t: sdfn(pos_at_t(t))

    stack = [coverage(t_end + dont_care, None), coverage(t_mid, sd_at_t(t_mid))]
    target = coverage(0.0, None)

    max_stack = len(stack)
    iterations = 0
    sdfn_calls = 1

    while len(stack):
        iterations += 1
        if (stack[-1].low - dont_care) <= target.high:
            target = stack.pop()
            #print("pop: {}".format(target))
            if target.sign < 0:
                break
        else:
            t_next = (stack[-1].low + target.high) * 0.5
            sd_next = sd_at_t(t_next)
            sdfn_calls += 1
            fnord = coverage(t_next, sd_next)
            if stack[-1].sign == fnord.sign and (stack[-1].low - dont_care) <= fnord.high:
                stack[-1].low = fnord.low
                #print("merged: {}".format(stack[-1]))
            else:
                stack.append(coverage(t_next, sd_next))
                #print("push: {}".format(stack[-1]))
                max_stack = max(max_stack, len(stack))

    cmp = search(ray_start, ray_end, ray_dir, sdfn)[-1]
    if cmp is not None:
        print("Ref Hit: {} -> {}".format(pos_at_t(cmp.tx), pretty_float(cmp.sd)))
    else:
        print("Ref Miss")

    if target.sign == -1:
        t_hit = max(t_start, target.low)
        p_hit = pos_at_t(t_hit)
        sd_hit = sdfn(p_hit)
        print("Ray Hit: {} -> {}".format(p_hit, pretty_float(sd_hit)))
    else:
        print("Ray Miss")
    print("Max Stack: {}".format(max_stack))
    print("Iterations: {}".format(iterations))
    print("SDF Calls: {}".format(sdfn_calls))

    print("\n\n")
    


def sphere_march(ray_start, ray_end, ray_dir, sdfn):
    t_start = 0
    t_end = distance(ray_end, ray_start)
    t_mid = t_end * 0.5

    t_next = t_start
    dont_care = 0.001

    def new_sample(tx):
        global sample
        pos = add(ray_start, mul(ray_dir, tx))
        sdf = sdfn(pos)
        return sample(tx, sdf)

    samples = [new_sample(t_start)]
    while samples[-1].sd >= dont_care and t_next <= t_end:
        t_next += samples[-1].sd
        samples.append(new_sample(t_next))

    hit = None
    if samples[-1].sd < dont_care:
        hit = samples[-1]

    return "OLD", samples, hit


def report(run, trial, ray_start, ray_dir):
    name, samples, hit = trial
    print("--------------------------------------------------------------------------------")
    print("{}: {}".format(run.upper(), name.upper()))

    print("\n  samples: {}".format(len(samples)))
    if 0:
        for i, sample in enumerate(samples):
            print("    {}: {}".format(i, sample))

    if hit:
        print("\n  ray hit:")
        print("    {}".format(hit))
        dont_care = 0.001
        error = pretty_float(abs(hit.sd))
        print("    error: {}".format(error))

    else:
        print("\n  ray miss")

    print()


def case1():
    ray_start = (-1.0, -2.0, 0.0)
    ray_end = (1.0, 2.0, 0.0)
    ray_dir = normalize(sub(ray_end, ray_start))
    sdfn = lambda p: sdf_sphere(p, 1.0)
    rprt = lambda t: report("case 1", t, ray_start, ray_dir)
    rprt(sphere_march(ray_start, ray_end, ray_dir, sdfn))
    rprt(search(ray_start, ray_end, ray_dir, sdfn))


def case1a():
    ray_start = (-1.0, -2.0, 0.0)
    ray_end = (1.0, 2.0, 0.0)
    ray_dir = normalize(sub(ray_end, ray_start))
    sdfn = lambda p: sdf_sphere(p, 1.0)
    search2(ray_start, ray_end, ray_dir, sdfn)


def case2():
    ray_start = (1.0, -2.0, 0.0)
    ray_end = (1.0, 2.0, 0.0)
    ray_dir = normalize(sub(ray_end, ray_start))
    sdfn = lambda p: sdf_sphere(p, 1.0)
    rprt = lambda t: report("case 2", t, ray_start, ray_dir)
    rprt(sphere_march(ray_start, ray_end, ray_dir, sdfn))
    rprt(search(ray_start, ray_end, ray_dir, sdfn))


def case2a():
    ray_start = (1.0, -2.0, 0.0)
    ray_end = (1.0, 2.0, 0.0)
    ray_dir = normalize(sub(ray_end, ray_start))
    sdfn = lambda p: sdf_sphere(p, 1.0)
    search2(ray_start, ray_end, ray_dir, sdfn)


def case3():
    ray_start = (1.0, -2.0, 0.0)
    ray_end = (1.0, 2.0, 0.0)
    ray_dir = normalize(sub(ray_end, ray_start))
    sdfn = lambda p: sdf_sphere(p, 0.999)
    rprt = lambda t: report("case 3", t, ray_start, ray_dir)
    rprt(sphere_march(ray_start, ray_end, ray_dir, sdfn))
    rprt(search(ray_start, ray_end, ray_dir, sdfn))


def case3a():
    ray_start = (1.0, -2.0, 0.0)
    ray_end = (1.0, 2.0, 0.0)
    ray_dir = normalize(sub(ray_end, ray_start))
    sdfn = lambda p: sdf_sphere(p, 0.999)
    search2(ray_start, ray_end, ray_dir, sdfn)


def case4():
    ray_start = (0.0, -2.0, 0.0)
    ray_end = (0.0, 2.0, 0.0)
    ray_dir = normalize(sub(ray_end, ray_start))
    rprt = lambda t: report("case 4", t, ray_start, ray_dir)

    def sdfn(point):
        return sdf_union(
            sdf_sphere(translate(point, (-1.0, 1.0, 0.0)), 0.999),
            sdf_sphere(translate(point, (1.0, -1.0, 0.0)), 0.999),
            sdf_sphere(translate(point, (-1.0, 1.0, 0.0)), 0.999))

    rprt(sphere_march(ray_start, ray_end, ray_dir, sdfn))
    rprt(search(ray_start, ray_end, ray_dir, sdfn))


def case4a():
    ray_start = (0.0, -2.0, 0.0)
    ray_end = (0.0, 2.0, 0.0)
    ray_dir = normalize(sub(ray_end, ray_start))
    def sdfn(point):
        return sdf_union(
            sdf_sphere(translate(point, (-1.0, 1.0, 0.0)), 0.999),
            sdf_sphere(translate(point, (1.0, -1.0, 0.0)), 0.999),
            sdf_sphere(translate(point, (-1.0, 1.0, 0.0)), 0.999))
    search2(ray_start, ray_end, ray_dir, sdfn)


def case5():
    ray_start = (0.0, -2.0, 0.0)
    ray_end = (0.0, 2.0, 0.0)
    ray_dir = normalize(sub(ray_end, ray_start))
    sdfn = lambda p: sdf_box(p, (1.0, 1.0, 1.0))
    rprt = lambda t: report("case 5", t, ray_start, ray_dir)
    rprt(sphere_march(ray_start, ray_end, ray_dir, sdfn))
    rprt(search(ray_start, ray_end, ray_dir, sdfn))


def case5a():
    ray_start = (0.0, -2.0, 0.0)
    ray_end = (0.0, 2.0, 0.0)
    ray_dir = normalize(sub(ray_end, ray_start))
    sdfn = lambda p: sdf_box(p, (1.0, 1.0, 1.0))
    search2(ray_start, ray_end, ray_dir, sdfn)


def case6():
    ray_start = (0.0, -2.0, 0.0)
    ray_end = (0.0, 2.0, 0.0)
    ray_dir = normalize(sub(ray_end, ray_start))
    rprt = lambda t: report("case 6", t, ray_start, ray_dir)

    def sdfn(point):
        return sdf_box(translate(point, (1.0, 0.0, 0.0)), (0.999, 2.0, 1.0))

    rprt(sphere_march(ray_start, ray_end, ray_dir, sdfn))
    rprt(search(ray_start, ray_end, ray_dir, sdfn))


def case6a():
    ray_start = (0.0, -2.0, 0.0)
    ray_end = (0.0, 2.0, 0.0)
    ray_dir = normalize(sub(ray_end, ray_start))
    def sdfn(point):
        return sdf_box(translate(point, (1.0, 0.0, 0.0)), (0.999, 2.0, 1.0))
    search2(ray_start, ray_end, ray_dir, sdfn)


def case7():
    ray_start = (0.0, -2.0, 0.0)
    ray_end = (0.0, 2.0, 0.0)
    ray_dir = normalize(sub(ray_end, ray_start))
    rprt = lambda t: report("case 7", t, ray_start, ray_dir)

    def sdfn(point):
        return sdf_box(translate(point, (0.0, -1.9, 0.0)), (1.0, 0.01, 1.0))

    rprt(sphere_march(ray_start, ray_end, ray_dir, sdfn))
    rprt(search(ray_start, ray_end, ray_dir, sdfn))


def case7a():
    ray_start = (0.0, -2.0, 0.0)
    ray_end = (0.0, 2.0, 0.0)
    ray_dir = normalize(sub(ray_end, ray_start))
    def sdfn(point):
        return sdf_box(translate(point, (0.0, -1.9, 0.0)), (1.0, 0.01, 1.0))
    search2(ray_start, ray_end, ray_dir, sdfn)


if __name__ == "__main__":
    if 0:
        case1()
        case2()
        case3()
        case4()
        case5()
        case6()
        case7()
    else:
        case1a()
        case2a()
        case3a()
        case4a()
        case5a()
        case6a()
        case7a()
