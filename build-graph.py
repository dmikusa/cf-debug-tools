#!/usr/bin/env python
#
# A script to parse dump.sh data obtained from `cf logs`
#
#  Author:  Daniel Mikusa <dmikusa@pivotal.io>
#    Date:  2015-10-20
#
#  Script requires:  matplotlib & python-dateutil
#
import sys
import re
import matplotlib.pyplot as plt
from dateutil.parser import parse
from collections import OrderedDict

def read_data(filename, pid, region_names):
    """Read `cf logs` output when dump.sh is running"""
    # data storage
    jvm_totals = []
    top_totals = []
    x_series = []
    crashes = []
    region_totals = {}
    start_date = None

    # regexes used to parse some of the log output
    jnmt_pattern = re.compile(
        'Total: reserved=(-?\+?\d+[KM]B) (-?\+?\d+[KM]B), '
        'committed=(-?\+?\d+[KM]B) (-?\+?\d+[KM]B)')
    top_pattern = re.compile('OUT\s+%s\s+vcap\s+10\s+-10\s+(\d+?)'
                             '\s+(.*?)\s+(\d+?)\s+\w' % pid)
    crash_pattern = re.compile('"reason"=>"(.*?)", "exit_status"=>(-?\d+?),'
                               ' "exit_description"=>"(.*?)", "')
    memory_region_patterns = []
    for region_name in region_names:
        region_pattern = re.compile(
                '-\s+%s\s\(reserved=(-?\+?\d+[KM]B) (-?\+?\d+[KM]B), '
                'committed=(-?\+?\d+[KM]B) (-?\+?\d+[KM]B)\)' % region_name)
        memory_region_patterns.append(region_pattern)

    # loop through file and pick out important lines
    for line in open(filename, 'rt'):
        # grab first line with a valid date,
        #   the x-axis is seconds from this date
        if start_date is None and len(line.strip()) > 0:
            try:
                start_date = parse(line.split(' ')[0])
            except ValueError:
                pass
        # find Java NMT output and read total & diff's of memory
        if line.find('OUT Total: ') != -1:
            m = jnmt_pattern.search(line.strip())
            if m:
                jvm_totals.append(m.groups())
            else:
                print 'line [%s]' % line.strip()
            event_date = parse(line.split(' ')[0])
            x_series.append((event_date - start_date).seconds)
        # find `top` output for jvm process
        if line.find('OUT    %s vcap      10 -10' % pid) != -1:
            m = top_pattern.search(line.strip())
            if m:
                top_totals.append(m.groups())
            else:
                print 'line [%s]' % line.strip()
        # find crashes
        if line.find('OUT App instance exited ') != -1:
            m = crash_pattern.search(line.strip())
            if m:
                crash_date = parse(line.split(' ')[0])
                crashes.append(((crash_date - start_date).seconds,
                                m.group(1), m.group(2), m.group(3)))
        # find Java NMT memory regions output and read total & diff's of memory
        for index, region_name in enumerate(region_names):
            if line.find(region_name) != -1:
                m = memory_region_patterns[index].search(line.strip())
                if m:
                    region_totals.setdefault(region_name, []).append(m.groups())
    max_len = len(x_series)
    for key in region_totals:
        region_totals[key] = region_totals[key][0:max_len]
    return (x_series,
            jvm_totals[0:max_len],
            top_totals[0:max_len],
            crashes[0:max_len],
            region_totals,
            start_date)


def fix_jvm(fig):
    """Normalize memory usage reported by Java NMT to KB"""
    if fig.upper().endswith('MB'):
        return int(fig.strip('MB')) * 1024
    if fig.upper().endswith('KB'):
        return int(fig.strip('KB'))
    if fig.upper().endswith('B'):
        return int(fig.strip('B')) / 1024


def fix_top(fig):
    """Normalize memory usage reported by `top` to KB"""
    if fig.endswith('m'):
        return float(fig.strip('m')) * 1024
    else:
        return int(fig)


def plot_jvm_graph(x_series, y_series, crashes, title, filename):
    """Creates a plot based on the x & y data passed in

    Creates a plot with one x_series of data and multiple y_series' of data.

    y_series should be a dictionary containing a key for each plot of data.
    All of the plots need to have the same length.  Each data set is on its
    own graph, graphs are top down for easy comparison.
    """

    figsize = 3 * len(y_series)
    plt.rcParams["figure.figsize"] = [figsize, figsize]
    plt.title("Java Memory Usage Over Time")
    plt.xlabel("Iteration")

    for i, (label, series) in enumerate(y_series.iteritems()):
        plt.subplot(len(y_series), 1, (i + 1))
        plt.plot(x_series, series)
        plt.ylabel(label)
        # plot crash lines
        for crash in crashes:
            plt.axvline(crash[0], color='r')

    plt.savefig(filename)
    plt.close()


def dump_data_to_csv(xseries, yseries, crashes):
    with open('dump.csv', 'wt') as fout:
        fout.write("seconds,reserved_total,reserved_diff,"
                   "committed_total,committed_diff,top_res\n")
        for i, xpt in enumerate(xseries):
            data = []
            data.append(str(xpt))
            for item in yseries:
                try:
                    data.append(str(item[i]))
                except IndexError:
                    print "Row [%s] missing info.  Should have record [%d]" % (
                        item, i)
            fout.write(",".join(data) + "\n")


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print
        print "USAGE:"
        print "\tpython build-dump-graphs.py <data-file> <pid> [region names]"
        print
        sys.exit(-1)

    (x_series, jvm_totals, top_totals, crashes, region_totals, start_date) = \
        read_data(sys.argv[1], sys.argv[2], sys.argv[3:])

    print "Generating graphs..."
    print "   Found %d data points." % len(x_series)
    print "   Found %d crashes." % len(crashes)
    print "      %s" % \
        "\n      ".join(["%s - %s [%s]" % (c[1], c[2], c[3]) for c in crashes])
    print "   Data starts at %s, times in graphs listed in seconds from" \
          " this mark." % start_date

    # dump data to csv for review
    dump_data_to_csv(
        x_series,
        (
            [fix_jvm(item[0]) for item in jvm_totals],
            [fix_jvm(item[1]) for item in jvm_totals],
            [fix_jvm(item[2]) for item in jvm_totals],
            [fix_jvm(item[3]) for item in jvm_totals],
            [fix_top(item[1]) for item in top_totals]
        ),
        crashes)

    memory_regions = OrderedDict()
    memory_regions.update({
        "reserved": [fix_jvm(item[0]) for item in jvm_totals],
        "committed": [fix_jvm(item[2]) for item in jvm_totals],
        "top RES": [fix_top(item[1]) for item in top_totals]
    })
    for region_name in region_totals:
        for item in region_totals[region_name]:
            memory_regions.setdefault(region_name + "\nreserved", []).append(fix_jvm(item[0]))
            memory_regions.setdefault(region_name + "\ncommitted", []).append(fix_jvm(item[2]))

    # graph the Java NMT totals w/top RES output
    plot_jvm_graph(x_series,
                   memory_regions,
                   crashes,
                   "Total JVM Memory Usage Over Time",
                   'mem-graph-jvm-total-res.png')

    memory_regions = OrderedDict()
    memory_regions.update({
        "reserved": [fix_jvm(item[1]) for item in jvm_totals],
        "committed": [fix_jvm(item[3]) for item in jvm_totals],
        "top RES": [fix_top(item[1]) for item in top_totals]
    })
    for region_name in region_totals:
        for item in region_totals[region_name]:
            memory_regions.setdefault(region_name + "\nreserved", []).append(fix_jvm(item[1]))
            memory_regions.setdefault(region_name + "\ncommitted", []).append(fix_jvm(item[3]))

    # graph the Java NMT diffs w/top RES output
    plot_jvm_graph(x_series,
                   memory_regions,
                   crashes,
                   "Differential Memory Usage Over Time",
                   'mem-graph-jvm-diff-res.png')
    print "Done!"
